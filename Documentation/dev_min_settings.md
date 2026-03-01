# Recommended development settings

Edit postgresql.conf (brew):

``` bash
brew --prefix postgresql@18
```

Example:

``` code
/opt/homebrew/etc/postgresql@18/postgresql.conf
```

Useful minimum settings:

``` conf
shared_buffers = 256MB
work_mem = 16MB
maintenance_work_mem = 256MB
max_connections = 100
``` 

Restart:

``` bash
brew services restart postgresql@18
```
