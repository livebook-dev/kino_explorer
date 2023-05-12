# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.6](https://github.com/livebook-dev/kino_explorer/tree/v0.1.6) (2023-05-13)

### Added

* Download data ([#84](https://github.com/livebook-dev/kino_explorer/pull/84))

### Fixed

* Correctly handles `Datetime` in filters ([#82](https://github.com/livebook-dev/kino_explorer/pull/82))
* Correctly handles `Time` in filters ([#83](https://github.com/livebook-dev/kino_explorer/pull/83))


## [v0.1.5](https://github.com/livebook-dev/kino_explorer/tree/v0.1.5) (2023-05-11)

### Added

* Queried filters ([#67](https://github.com/livebook-dev/kino_explorer/pull/67))
* Filter by quantile ([#68](https://github.com/livebook-dev/kino_explorer/pull/68))
* Allow any data structure that implements `Table.Reader` ([#75](https://github.com/livebook-dev/kino_explorer/pull/75))
* Allow `categorical` on `pivot_wider` ([#77](https://github.com/livebook-dev/kino_explorer/pull/77))

### Changed

* Allow `summarise` anywhere ([#71](https://github.com/livebook-dev/kino_explorer/pull/71))

### Fixed

* Correctly handles `nil` in summaries ([#72](https://github.com/livebook-dev/kino_explorer/pull/72))
* Correctly handles lazy data frames ([#78](https://github.com/livebook-dev/kino_explorer/pull/78))

## [v0.1.4](https://github.com/livebook-dev/kino_explorer/tree/v0.1.4) (2023-04-04)

### Fixed

* Correctly toggles `summarise` ([#60](https://github.com/livebook-dev/kino_explorer/pull/60))

## [v0.1.3](https://github.com/livebook-dev/kino_explorer/tree/v0.1.3) (2023-04-04)

### Added

* `group_by` and `summarise` operations for Data Transform cell ([#50](https://github.com/livebook-dev/kino_explorer/pull/50))
* Show if a column is in a group on DataTable header ([#53](https://github.com/livebook-dev/kino_explorer/pull/53))
* More aggregations for `summarise` ([#58](https://github.com/livebook-dev/kino_explorer/pull/58))

### Changed

* `pivot_wider` now supports multiple `values_from` ([#47](https://github.com/livebook-dev/kino_explorer/pull/47))

## [v0.1.2](https://github.com/livebook-dev/kino_explorer/tree/v0.1.2) (2023-03-18)

### Changed

* Automatically generates missing requires ([#45](https://github.com/livebook-dev/kino_explorer/pull/45))
* Starts the Data transform cell with only the filter operation ([#46](https://github.com/livebook-dev/kino_explorer/pull/46))

## [v0.1.1](https://github.com/livebook-dev/kino_explorer/tree/v0.1.1) (2023-03-11)

### Fixed

* Correctly toggles `pivot_wider` ([#41](https://github.com/livebook-dev/kino_explorer/pull/41))

## [v0.1.0](https://github.com/livebook-dev/kino_explorer/tree/v0.1.0) (2023-03-07)

Initial release.
