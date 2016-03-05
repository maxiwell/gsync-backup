README
==========

It's a personal bash project to drive my backups. 
The configuration file has explications about the field. 

Usage:
-------

```bash
Usage:
    gsync-backup.sh [--enable-git] /path/to/config
```

Some tips:
-----------

GSync Backup has the experimental flag ``--enable-git``.
It creates a repository in the server side and commits the changes made by ``rsync.``
The git repository doesn't have ``remote`` server, so the command ``push`` isn't executed. 

**Be Careful:** Big folders will generate big **.git** and will burn your CPU in the first time. 



