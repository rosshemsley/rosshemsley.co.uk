---
title: "The maximum likelihood interpretation of training neural networks"
date: 2019-01-13T19:08:15Z
draft: true
mathjax: true
---

Many texts on deep learning refer to training neural networks as applying the _maximum likelihood principle_[^1], followed by some rather hand-wavy justification. It wasn't until I read through my copy of Deep Learning that everything finally fell into place for me. Whilst this is far from an original subject, I decdided to write this up as a post to 1) force myself to master all of the details and 2) make it easier for the next person that stumbles across this corner of the internet.

The first thing that stumped me was untangling the different probability distributions involved in training. Deep Learning by Goodfellow et al. does an excellent job of this.

Let's start with some simple assumptions. We will consider a _supervised_ learning problem, in which we have a set of inputs $x\_i \in \mathbf{R}^n$, and a set of associated labeled outcomes $y\_i \in \mathbf{R}$, for $i = 1 \dots m$. Our goal is to find a function, $f^*$ such that,

$$ y\_i \approx f^*(x\_i) $$

for all $i=1\dots m$.

$$ \operatorname{\underset{\theta}{\operatorname{argmax}}} \operatorname{\mathbb{E}}\left[\,p(y \mid x;\, \theta)\,\right] $$

[^1]: Example