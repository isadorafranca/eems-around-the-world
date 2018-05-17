# EEMS-AROUND-THE-WORLD
# vAPE
**Visualizing population structures using Admixture, PCA, and EEMS**


## Overview
1. [Goal](#Goal)
2. [What does my input data have to look like?](#What does my input data have to look like?)
3. [Getting started: Configuring the workflow to fit your data](#Getting-started:-Configuring-the-workflow-to-fit-your-data)
4. 

----

## Goal

The vAPE workflow brings together a number visualization tools commonly used in population structure analyses. The goal is to allow for a easy and reliable generation of a number of different plots and graphs from one input dataset, giving you a general overview over your data set.

The main focus lies on the following methods:
- [EEMS](http://github.com/dipetkov/eems)
- [flashpca](https://github.com/gabraham/flashpca)
- [admixture](https://www.genetics.ucla.edu/software/admixture/)

Others include (?):
- [pong](https://pypi.python.org/pypi/pong) visualization of admixture
- [TESS3](https://github.com/cayek/TESS3/)
- [treemix](https://bitbucket.org/nygcresearch/treemix/wiki/Home)
- [Spacemix](https://github.com/gbradburd/SpaceMix)
- [conStruct](https://github.com/gbradburd/conStruct)
- FST using [plink](https://www.cog-genomics.org/plink/1.9/)

----

## Implementation

The vAPE pipeline is implemented using [Snakemake](https://bitbucket.org/snakemake),
using `python` for most data wrangling and `R` for most plotting.

----

## What does my input data have to look like?

### Genotypes

Genotypes must be provided in binary [plink](https://www.cog-genomics.org/plink2) format, which is comprised of the following three file types:

1. *filename.bed* (Do not confuse this with the UCSC Genome Browser's BED format, which is completely different.)

2. *filename.bim*

3. *filename.fam*


### Meta data

The meta data - holding information on individuals and populations in your sample - must be provided in an adaption of the  [PopGenStructures](https://docs.google.com/document/d/1wPlI1hLr19JIdM2EzYKlPnzzbR6L2ZOgOGkC6kbhHE4/edit) format as follows:

1. *filename.indiv_meta*:
> `sampleId,source,used,originalId,permissions,popId`

2. *filename.pop_meta*
> `"popId","name","abbrev","color","colorAlt","order","latitude","longitude","accuracy"`


TODO: delete the following and replace with either .indiv_meta or .pop_meta:
- *filename.pop_display*
> `"popId","name","abbrev","color","colorAlt","order"`
- *filename.pop_geo*
> `"popId","latitude","longitude","accuracy"`
-  *filename.indiv_label*:
>`"sampleId","popId"`
- *filename.indiv_prov*
> `"sampleId","wasDerivedFrom","used","originalId","permissions"`



<font color="red">What is used, originalId, permissions, colorAlt, order? How is accuracy defined? </font>


### Maps

This workflow uses maps from .. to subset data using words like 'Asia' or 'India'. This implementation is dendent on maps in GIS format, so it is, in theory possible to use a different map. However, this will require quite a bit of hacking.

The maps from NaturalEarth are included in this workflow directory under 'subet/maps'


<font color="red">Default settings are included in package, but what format are they in?</font>
