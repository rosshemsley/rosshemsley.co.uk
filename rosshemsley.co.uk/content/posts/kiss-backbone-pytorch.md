---
title: "KISS: Backbones in Pytorch"
date: 2020-08-03T13:19:31+01:00
---

## Keep It Simple Stupid: CNN Backbones

Many modern CNNs (convolutional neural networks) use a _backbone_ to extract feature maps as the first step in their architecture: for example, some flavour of _Resnet50_.

<a title="Aphex34 / CC BY-SA (https://creativecommons.org/licenses/by-sa/4.0)" href="https://commons.wikimedia.org/wiki/File:Typical_cnn.png"><img width="512" alt="Typical cnn" src="https://upload.wikimedia.org/wikipedia/commons/thumb/6/63/Typical_cnn.png/512px-Typical_cnn.png"></a>

Helpfully, many of these backbones are implemented for us in [torchvision](https://pytorch.org/docs/stable/torchvision/models.html), even with pre-trained models made available. This means we can often write simple code that looks like the following:

{{< highlight python "linenos=table" >}}
from torchvision.models import resnet50
import torch.nn

def Model(nn.Module):
    def __init__(self):
        super(Model, self).__init__()

        self.backbone = resnet50(pretrained=False)
        self.fancy_net = nn.Sequential(...)
    
    def forward(x):
        return self.fancy_net(self.backbone(x))
{{< / highlight >}}

This makes it very easy to get started with building models that use the feature maps from the final layer of Resnet. However, in many cases, network architectures need to key into other layers from Resnet.
One example is in the use of [feature pyramids](https://arxiv.org/abs/1612.03144), where different scales are extracted from different layers of the backbone.

Many models implemented on Github will thus re-implement e.g. a Resnet backbone from scratch and copy it into their repo. However, there is an easier way!

As long as we trust the API stability of the `torchvision` package (and we can pin the version of our dependencies to guarantee this) it's possible to actually re-use the backbones provided by torch vision.
To do this, we simply create our own module holding the pretrained model internally, and then modify the forwards pass to call sequentially the same layers as the original model. The only difference is that we return more of the layers than the original

Here is an example of extracting multiple layers of feature maps from the torchvision resnet backbone without re-implement resnet from scratch.

{{< highlight python "linenos=table" >}}
import torch.nn as nn
from torchvision.models import resnet50


class Backbone(nn.Module):
    def __init__(self):
        super(Backbone, self).__init__()
        self.resnet = resnet50(pretrained=False)

    def forward(self, x):
        x = self.resnet.conv1(x)
        x = self.resnet.bn1(x)
        x = self.resnet.relu(x)
        x = self.resnet.maxpool(x)
        layer_1 = self.resnet.layer1(x)
        layer_2 = self.resnet.layer2(layer_1)
        layer_3 = self.resnet.layer3(layer_2)
        layer_4 = self.resnet.layer4(layer_3)

        return layer_2, layer_3, layer_4
{{< / highlight >}}

In this way, we can spend a lot less time debugging our backbones and get on with solving the problem at hand. Furthermore, users of the code can be confident that the backbone is implemented in the same way across different models.

For a full worked example, this is the same technique I used in my implementation of [FCOS](https://github.com/rosshemsley/fcos), which uses a feature pyramid.

