The RF RCTools module enables easy visualization/manipulation of RC files. It allows indexing, merging and dumping RC files.<br />
This tool is particularly useful when the same sample is sequenced more than one time to increase its coverage. Now, instead of merging the BAM files and re-calling the `rf-count` on the whole dataset (that is very time-consuming), each sample can be processed independently and simply merged to the RC file from the previous analysis.<br/>
# Usage
To list the required parameters, simply type:

```bash
$ rf-rctools [tool] -h
```
Available tools are: __index__, __view__ and __merge__

Parameter         | Tool | Type | Description
----------------: | :--: | :--: | :------------
__-t__ *or* __--tab__ | __view__ | | Switches to tabular output format
__-o__ *or* __--output__ | __merge__ | string | Output RC filename (Default: __merge.rc__)
__-ow__ *or* __--overwrite__ | __merge__ | | Overwrites output file (if the specified file already exists)
__-i__ *or* __--index_ | __merge__ | string[,string] | A comma separated (no spaces) list of RCI index files for the provided RC files<br/>__Note:__ RCI files must be provided in the same order as RC files. If a single RCI file is specified along with multiple RC files, it will be used for all of them.
__-T__ *or* __--tmp-dir__ | __merge__ | string | Temporary directory (Default: __/tmp__)