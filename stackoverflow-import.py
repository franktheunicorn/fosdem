# pulling questions from this API endpoint: https://api.stackexchange.com/docs/questions

import os
import time
import requests
from neo4j.v1 import GraphDatabase, basic_auth

neo4jUrl = os.environ.get('NEO4J_URL',"bolt://localhost")
neo4jUser = os.environ.get('NEO4J_USER',"neo4j")
neo4jPass = os.environ.get('NEO4J_PASSWORD',"test")
driver = GraphDatabase.driver(neo4jUrl, auth=basic_auth(neo4jUser, neo4jPass))

session = driver.session()

result = session.run("MATCH (q:Question) RETURN max(q.created) as max_date")

maxDate = None
for record in result:
    if record["max_date"] != None:
        maxDate = record["max_date"]

# Build query.
importQuery = """
WITH {json} as data
UNWIND data.items as q
MERGE (question:Question:Content:StackOverflow {id:q.question_id}) 
  ON CREATE SET question.title = q.title, question.url = q.share_link, question.created = q.creation_date
SET question.favorites = q.favorite_count, question.updated = q.last_activity_date

FOREACH (q_owner IN [o in [q.owner] WHERE o.user_id IS NOT NULL] |
  MERGE (owner:User:StackOverflow {id:q.owner.user_id}) ON CREATE SET owner.name = q.owner.display_name
  MERGE (owner)-[:POSTED]->(question)
)

FOREACH (tagName IN q.tags | MERGE (tag:Tag:StackOverflow {name:tagName}) MERGE (question)-[:TAGGED]->(tag))
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer:Content:StackOverflow {id:a.answer_id})
   FOREACH (a_owner IN filter(o IN [a.owner] where o.user_id is not null) |
     MERGE (answerer:User:StackOverflow {id:a_owner.user_id}) ON CREATE SET answerer.name = a_owner.display_name
     MERGE (answer)<-[:POSTED]-(answerer)
   )
)
"""

page=1
items=100
tag="Neo4j"
hasMore=True

while hasMore == True:
    # Build URL.
    apiUrl = "https://api.stackexchange.com/2.2/questions?page={page}&pagesize={items}&order=asc&sort=creation&tagged={tag}&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf".format(tag=tag,page=page,items=items)
#    if maxDate <> None:
#        apiUrl += "&min={maxDate}".format(maxDate=maxDate)
    apiUrl
    # Send GET request.
    response = requests.get(apiUrl, headers = {"accept":"application/json"})
    print(response.status_code)
    if response.status_code != 200:
        print(response.text)
    json = response.json()
    print("has_more",json.get("has_more",False),"quota",json.get("quota_remaining",0))
    if json.get("items",None) != None:
        print(len(json["items"]))
        result = session.run(importQuery,{"json":json})
        print(result.consume().counters)
        page = page + 1
        
    hasMore = json.get("has_more",False)
    print("hasMore: {more} page {page}".format(page=page,more=hasMore))
    if json.get('quota_remaining',0) <= 0:
        time.sleep(10)
    if json.get('backoff',None) != None:
        print("backoff",json['backoff'])
        time.sleep(json['backoff']+5)

session.close()
