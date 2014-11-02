var maths = document.querySelectorAll(".katex");

for (var i = 0; i < maths.length; i++) {
    var node = maths[i];
    var text = node.textContent;
    
    try {
        katex.render(text, node);
    } catch (e) {
        if (e instanceof katex.ParseError) {
            node.textContent = e.toString();
        } else {
            node.textContent = text;
        }
    }
}