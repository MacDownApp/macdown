
# Graph Visualization

Two graph visualization grammer are supported, mermaid and graphviz.
To enable these features, options `Mermaid` and/or `Graphviz` in `MacDown` -> `Perferences...` -> `Rendering` should be checked.

# Mermaid

[mermaid](https://github.com/knsv/mermaid) has 3 diagram syntax.

## Flow Chart


```mermaid
graph TD;
A-->B;
A-->C;
B-->D;
C-->D;
```

## Sequence Diagram

```mermaid
sequenceDiagram
participant Alice
participant Bob
Alice->>John: Hello John, how are you?
loop Healthcheck
John->>John: Fight against hypochondria
end
Note right of John: Rational thoughts <br/>prevail...
John-->>Alice: Great!
John->>Bob: How about you?
Bob-->>John: Jolly good!
```

## Gantt

```mermaid
gantt
title A Gantt Diagram

section Section
A task           :a1, 2014-01-01, 30d
Another task     :after a1  , 20d
section Another
Task in sec      :2014-01-12  , 12d
anther task      : 24d
```

# Graphviz
> Graphviz is open source graph visualization software. Graph visualization is a way of representing structural information as diagrams of abstract graphs and networks. It has important applications in networking, bioinformatics,  software engineering, database and web design, machine learning, and in visual interfaces for other technical domains.


Please refer to [Graphviz website](http://www.graphviz.org/Home.php) for details.

## Graphviz Engines

* circo
* dot
* fdp
* neato
* osage
* twopi

Here are some samples.

## Hashmap


```dot
digraph G {
nodesep=.05;
rankdir=LR;

node [shape=record,width=1.1,height=.1];
node0 [label = "<f0> |<f1> |<f2> |<f3> |<f4> |<f5> |<f6> | ", height=2.5];

node [width = 1.5];
node1 [label = "{<n> n14 | 719 |<p> }"];
node2 [label = "{<n> a1 | 805 |<p> }"];
node3 [label = "{<n> i9 | 718 |<p> }"];
node4 [label = "{<n> e5 | 989 |<p> }"];
node5 [label = "{<n> t20 | 959 |<p> }"] ;
node6 [label = "{<n> o15 | 794 |<p> }"] ;
node7 [label = "{<n> s19 | 659 |<p> }"] ;

node0:f0 -> node1:n;
node0:f1 -> node2:n;
node0:f2 -> node3:n;
node0:f5 -> node4:n;
node0:f6 -> node5:n;
node2:p -> node6:n;
node4:p -> node7:n;
}
```

## Process diagram with clusters


```dot
digraph G {

subgraph cluster0 {
  node [style=filled,color=white];
  style=filled;
  color=lightgrey;
  a0 -> a1 -> a2 -> a3;
  label = "process #1";
}

subgraph cluster1 {
  node [style=filled];
  b0 -> b1 -> b2 -> b3;
  label = "process #2";
  color=blue
}

start -> a0;
start -> b0;
a1 -> b3;
b2 -> a3;
a3 -> a0;
a3 -> end;
b3 -> end;
start [shape=Mdiamond];
end [shape=Msquare];
}

```


