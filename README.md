qless-sharded-ui
=====

For large shared Qless installations, qless-sharded-ui provides a way to
view all your Qless shards on one UI.

It is driven by a simple yaml file, where you list the redis urls:

```
$ qless-sharded-web --init qless-sharded-web.yml
$ # Edit qless-sharded-web.yml to taste
$ qless-sharded-web --config qless-sharded-web.yml
```
