Next Release
------------

1.0.1
-----

* [#8](https://github.com/aaw/mongoid_collection_snapshot/pull/8): Fixed .gemspec for compatibility with Mongoid 4.x - [@dblock](https://github.com/dblock).

1.0.0
-----

* Expose `snapshot_session` for custom snapshot storage - [@joeyAghion](https://github.com/joeyAghion)
* Compatibility with Mongoid 4.x - [@dblock](https://github.com/dblock).

0.2.0
-----

Important note for those upgrading from 0.1.0 (pre-Mongoid 3.0) to 0.2.0 (Mongoid 3.x): you'll need to upgrade any
existing snapshots created by mongoid_collection_snapshot 0.1.0 in your database before they're usable. You can
do this by renaming the 'workspace_slug' attribute to 'slug' in MongoDB after upgrading. For example,
to upgrade the snapshot class "MySnapshot", you'd enter the following at the mongo shell:

    db.my_snapshot.rename({'workspace_slug': {'$exists': true}}, {'$rename': {'workspace_slug': 'slug'}})

* Added ability to maintain a snapshot of multiple collections atomically - [@aaw](https://github.com/aaw).
* Added support for [Mongoid 3.0](https://github.com/mongoid/mongoid) - [@dblock](https://github.com/dblock).
* Relaxed version limitations of [mongoid_slug](https://github.com/digitalplaywright/mongoid-slug) - [@dblock](https://github.com/dblock).

0.1.0
-----

* Initial public release - [@aaw](https://github.com/aaw).
