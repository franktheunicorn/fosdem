let links = [...document.querySelectorAll('a[href]')];
links = links.filter(a => a.href.startsWith("http"));
for(var i = links.length; i--;) {
  var link = links[i];
  console.log({ href: link.href, target: link.target});
}
