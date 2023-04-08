# Mongoid Community Edition
[![Gem Version][rubygems-img]][rubygems-url]
[![Inline Docs][inch-img]][inch-url]
[![License][license-img]][license-url]

The no-baloney fork of Mongoid. Made by the community, for the community.
Mongoid is the Ruby Object Document Mapper (ODM) for MongoDB.

This fork of Mongoid is **not** endorsed by or affiliated with MongoDB Inc. 👍

## Installation

Replace `gem 'mongoid'` in your application's Gemfile with:

```ruby
gem 'mongoid-ce'
```

(Do not install `mongoid` and `mongoid-ce` at the same time.)

## Compatibility

- Ruby (MRI) 2.7 - 3.2
- JRuby 9.4
- MongoDB server 4.4 - 6.0

Version support may differ from MongoDB's official Mongoid release.

## Purpose & Principles

This is a *community-driven fork of Mongoid*, intend to improve the following over MongoDB's official Mongoid:

- Feature robustness
- Code quality
- Behavioral rationality
- Developer experience
- Stability
- Transparency
- Community involvement

This fork will merge in changes at least once-per-month from [mongodb/mongoid](https://github.com/mongodb/mongoid)
as its "upstream" repo. We may backport PRs to upstream where it makes sense to do so, but cannot guarantee that
the upstream will merge them.

## Versioning

For the time being, version numbers will shadow those of `mongodb/mongoid` with an additional "patch" number added:

`X.Y.Z.P`

Where `X.Y.Z` is the latest upstream release version, and `P` is the patch version of this repo.
We will also use `-beta1`, `-rc1`, etc. suffixes which will not necessarily be aligned with upstream.

**Semver**: For the time being will follow the major version component of semver, i.e. not breaking or
removing functionality *except* in major (`X`) releases. We may introduce new features in new patch (`P`) releases,
and will use feature flags prefixed with `ce_` to allow users to opt-in.

All new versions will undergo battle-testing in production at TableCheck prior to being released.

## Roadmap

- [x] Use a publicly visible CI (Github Actions) as the primary CI.
- [ ] Remove Evergreen CI, MRSS submodule, and other MongoDB corporate baloney.
- [ ] Publish documentation.
- [ ] Drop support for old Ruby, Rails, and MongoDB server versions.
- [ ] Full documentation coverage.
- [ ] Full Rubocop compliance and coverage.
- [ ] Remove all monkey-patching.
- [ ] Merge patches rejected by MongoDB.
- [ ] Refactor persistence type-validation (mongoize, etc.)
- [ ] Extract unsafe chaining `and` and `or` operators to a gem. Require usage of `all_of` and `any_of` instead.
- [ ] Extract `:field.in => [1, 2, 3]` query syntax to a gem. Require usage of `field: { '$in' => [1, 2, 3] }` instead.
- [ ] Allow symbol instead of classes in `field :type` declarations.
- [ ] Refactor relations (`belongs_to_one`, `belongs_to_many`)

## Documentation

The documentation of this fork will be hosted at: https://tablecheck.github.io/mongoid-ce/ (not online yet!)

## Notable Differences from MongoDB Mongoid

- At the moment, none. We are working on it!

## Support

For beginners, please use MongoDB's existing Mongoid support resources:

* [Stack Overflow](http://stackoverflow.com/questions/tagged/mongoid)
* [MongoDB Community Forum](https://developer.mongodb.com/community/forums/tags/c/drivers-odms-connectors/7/mongoid-odm)
* [#mongoid](http://webchat.freenode.net/?channels=mongoid) on Freenode IRC

## Maintainership

Mongoid CE is shepherded by the team at TableCheck. TableCheck have been avid Mongoid users since 2013,
contributing over 150 PRs to Mongoid and MongoDB Ruby projects. TableCheck uses Mongoid to power millions of
restaurant reservations each month, and are *personally invested* in the making the best user experience possible.

We invite all in the community to apply for co-maintainership, please raise a Github issue if interested.

## Reasons for Forking

Mongoid started as an open-source project created by Durran Jordan in 2009. MongoDB Inc. took over maintainership in 2015.
Since the transition, the hallmarks of user-disconnect and corporate fumbling have become apparent:

- Introduction of [critical semver-breaking issues](https://serpapi.com/blog/how-a-routine-gem-update-ended-up-charging/).
- Lack of a publicly visible roadmap or direction (when requested, it was said to be a "corporate secret".)
- Unwillingness to adopt basic best industry-standard practices, e.g. Rubocop linter and a publicly-visible CI workflow.
- Refusal to merge patches which would be of obvious benefit to the community.
- Lack of bandwidth and resources to review simple PR contributions.

**None of this is intended to disparage the hard-working and talented individuals at MongoDB Inc.**, but rather,
to illustrate that the corporate rules, philosophy, and priorities of MongoDB Inc. are simply not aligned with the needs
of its Ruby users.

It's time to do better!

## Issues & Contributing

Feature requests and bugs affecting both upstream and Mongoid CE should be reported in the [MongoDB MONGOID Jira](https://jira.mongodb.org/browse/MONGOID/).
Please also raise a [Mongoid CE Github issue](https://github.com/tablecheck/mongoid-ce/issues) in this project to track the fix. We prefer if upstream can make the fix first then we merge it.

Issues specific to Mongoid CE should be raised in the [Mongoid CE Github issue tracker](https://github.com/tablecheck/mongoid-ce/issues)

## Security Issues

Security issues affecting both upstream and Mongoid CE should be
[reported to MongoDB](https://www.mongodb.com/docs/manual/tutorial/create-a-vulnerability-report/).

Security issues affecting only Mongoid CE should be reported to [security@tablecheck.com](mailto:security@tablecheck.com).
The email should be encrypted with our PGP public key as follows:

* Key ID: `0xDF7D22A0E8772326`
* Fingerprint: `466C 56B9 E110 3CBA 2129 DBAD DF7D 22A0 E877 2326`

We appreciate your help to disclose security issues responsibly.

[rubygems-img]: https://badge.fury.io/rb/mongoid-ce.svg
[rubygems-url]: http://badge.fury.io/rb/mongoid-ce
[inch-img]: http://inch-ci.org/github/tablecheck/mongoid-ce.svg?branch=master
[inch-url]: http://inch-ci.org/github/tablecheck/mongoid-ce
[license-img]: https://img.shields.io/badge/license-MIT-green.svg
[license-url]: https://www.opensource.org/licenses/MIT
