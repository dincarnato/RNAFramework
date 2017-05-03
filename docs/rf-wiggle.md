The RF Wiggle module can process both RC or ``rf-norm`` output XML files to produce WIGGLE tracks. When provided with RC files, by default RF Wiggle reports the per-base raw RT-stop/mutation count.<br />
RF Wiggle can be invoked both on individual RC/XML files, or on the entire ``rf-norm`` output XML folder.
<br /><br />

# Usage
To list the required parameters, simply type:

```bash
$ rf-wiggle -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-o__ *or* __--output-dir__ | string | Output WIGGLE file (Default: __\<input\>.wig__)
__-ow__ *or* __--overwrite__ | | Overwrites output file (if the specified file already exists)
__-c__ *or* __--coverage__ | | Reports per-base coverage instead of RT-stop/mutation count<br/>__Note:__ this option only works for RC files.
__-r__ *or* __--ratio__ | | Reports per-base ratio between RT-stop/mutation count and coverage<br/>__Note:__ this option only works for RC files.