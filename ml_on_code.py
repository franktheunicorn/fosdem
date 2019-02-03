from sklearn.metrics import classification_report
from sklearn.cross_validation import train_test_split
from pyspark.sql import SparkSession

from sourced.stack import Engine

spark = SparkSession \
        .builder \
        .appName("PythonWordCount") \
        .getOrCreate()

engine = Engine(spark, "/public/git/archive", "siva")
train, val = train_test_split(engine.repositories.filter("is_fork = false")
                              .classify_languages()
                              .filter("lang = 'Python'")
                              .extract_uasts()
                              .collect())
train_batch_gen = batch_preprocessing(train)
for epoch in range(n):
    for X, y in train_batch_gen:
        model.fit(X, y)
    log.info(classification_report(val.y, model.predict(val.X)))

