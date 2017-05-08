The RF Wiggle module can process both RC or ``rf-norm`` output XML files to produce WIGGLE tracks. When provided with RC files, by default RF Wiggle reports the per-base raw RT-stop/mutation count.<br />
RF Wiggle can be invoked both on individual RC/XML files, or on the entire ``rf-norm`` output XML folder. <br/>Multiple RC/XML files can be provided at the same time.
<br /><br />

!!! note "Note"
    Input file names will be stripped of their extensions, and automatically used to generate output WIGGLE files.
<br/>
# Usage
To list the required parameters, simply type:

```bash
$ rf-wiggle -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-ow__ *or* __--overwrite__ | | Overwrites output file (if the specified file already exists)
__-c__ *or* __--coverage__ | | Reports per-base coverage instead of RT-stop/mutation count<br/>__Note:__ this option only works for RC files.
__-r__ *or* __--ratio__ | | Reports per-base ratio between RT-stop/mutation count and coverage<br/>__Note:__ this option only works for RC files.