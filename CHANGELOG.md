# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.20](https://github.com/livebook-dev/kino_explorer/tree/v0.1.20) (2024-06-17)

### Added

- Made multi-select fields draggable ([#161](https://github.com/livebook-dev/kino_explorer/pull/161))
- Support for relocating columns ([#163](https://github.com/livebook-dev/kino_explorer/pull/163))
- Added `Kino.Explorer.update/2` for updating table contents programmatically ([#164](https://github.com/livebook-dev/kino_explorer/pull/164))

### Changed

- Export to respect rows order ([#162](https://github.com/livebook-dev/kino_explorer/pull/162))

## [v0.1.19](https://github.com/livebook-dev/kino_explorer/tree/v0.1.19) (2024-04-09)

### Fixed

- Disables DataTransform Cell form submission ([#157](https://github.com/livebook-dev/kino_explorer/pull/157))
- Restore whether the variable is a dataframe on load ([#159](https://github.com/livebook-dev/kino_explorer/pull/159))

## [v0.1.18](https://github.com/livebook-dev/kino_explorer/tree/v0.1.18) (2024-01-22)

### Fixed

- Remove unsupported csv export ([#152](https://github.com/livebook-dev/kino_explorer/pull/152))

## [v0.1.17](https://github.com/livebook-dev/kino_explorer/tree/v0.1.17) (2024-01-21)

### Added

- Supports operations for `:struct` ([#147](https://github.com/livebook-dev/kino_explorer/pull/147))

### Fixed

- Update `data_options` after deleting an operation ([#148](https://github.com/livebook-dev/kino_explorer/pull/148))

## [v0.1.16](https://github.com/livebook-dev/kino_explorer/tree/v0.1.16) (2024-01-20)

### Added

- Supports operations for `:list` ([#136](https://github.com/livebook-dev/kino_explorer/pull/136))
- Supports filters for `:list` ([#142](https://github.com/livebook-dev/kino_explorer/pull/142))
- Initial support for `Explorer` `:struct` ([#143](https://github.com/livebook-dev/kino_explorer/pull/143))

### Fixed

- Renders summaries correctly whe the column is a list ([#137](https://github.com/livebook-dev/kino_explorer/pull/137))
- Handle summaries edge cases ([#138](https://github.com/livebook-dev/kino_explorer/pull/138))

## [v0.1.15](https://github.com/livebook-dev/kino_explorer/tree/v0.1.15) (2024-01-05)

### Fixed

- Remove unsupported csv export ([#130](https://github.com/livebook-dev/kino_explorer/pull/130))
- Fixes for list-type columns ([#131](https://github.com/livebook-dev/kino_explorer/pull/131))

## [v0.1.14](https://github.com/livebook-dev/kino_explorer/tree/v0.1.14) (2024-01-02)

### Added

- Supports `Explorer` type of `:list` ([#126](https://github.com/livebook-dev/kino_explorer/pull/126))

### Fixed

- Fix for nif_panicked error for categorical data ([#123](https://github.com/livebook-dev/kino_explorer/pull/123))
- Remove lists from unsupported operations ([#127](https://github.com/livebook-dev/kino_explorer/pull/127))


## [v0.1.13](https://github.com/livebook-dev/kino_explorer/tree/v0.1.13) (2023-12-03)

### Added

- Add support for `not contains` in `filter_by` operation ([#115](https://github.com/livebook-dev/kino_explorer/pull/115))
- Add `select` operation ([#116](https://github.com/livebook-dev/kino_explorer/pull/116))
- Supports new `Explorer` types ([#119](https://github.com/livebook-dev/kino_explorer/pull/119))

### Changed

- Remove the restriction on `pivot_wider` dtypes ([#114](https://github.com/livebook-dev/kino_explorer/pull/114))

## [v0.1.12](https://github.com/livebook-dev/kino_explorer/tree/v0.1.12) (2023-10-31)

### Fixed

- Showing non-utf8 binaries ([#112](https://github.com/livebook-dev/kino_explorer/pull/112))

## [v0.1.11](https://github.com/livebook-dev/kino_explorer/tree/v0.1.11) (2023-09-26)

### Added

- Export the dataframe inspected representation ([#109](https://github.com/livebook-dev/kino_explorer/pull/109))

### Fixed

- Use DF.lazy instead of DF.to_lazy ([#111](https://github.com/livebook-dev/kino_explorer/pull/111))
- Small UI adjustments ([#110](https://github.com/livebook-dev/kino_explorer/pull/110))
- Do not crash on invalid tabular data ([#106](https://github.com/livebook-dev/kino_explorer/pull/106))

## [v0.1.10](https://github.com/livebook-dev/kino_explorer/tree/v0.1.10) (2023-09-01)

### Fixed

- Export lazy data frames ([#101](https://github.com/livebook-dev/kino_explorer/pull/101))

## [v0.1.9](https://github.com/livebook-dev/kino_explorer/tree/v0.1.9) (2023-08-31)

### Changed

- Changes `:datetime` dtype into `{:datetime, precision}` ([#98](https://github.com/livebook-dev/kino_explorer/pull/98))

## [v0.1.8](https://github.com/livebook-dev/kino_explorer/tree/v0.1.8) (2023-07-07)

### Added

- Lazy by default ([#93](https://github.com/livebook-dev/kino_explorer/pull/93))

### Changed

- Allow `summarise` without `group_by` ([#91](https://github.com/livebook-dev/kino_explorer/pull/91))

### Fixed

- `df_build` respects alias ([#92](https://github.com/livebook-dev/kino_explorer/pull/92))

## [v0.1.7](https://github.com/livebook-dev/kino_explorer/tree/v0.1.7) (2023-05-26)

### Added

- Discard operation ([#87](https://github.com/livebook-dev/kino_explorer/pull/87))

### Fixed

- Correctly handles grouped multi-select operations ([#88](https://github.com/livebook-dev/kino_explorer/pull/88))

## [v0.1.6](https://github.com/livebook-dev/kino_explorer/tree/v0.1.6) (2023-05-13)

### Added

- Download data ([#84](https://github.com/livebook-dev/kino_explorer/pull/84))

### Fixed

- Correctly handles `Datetime` in filters ([#82](https://github.com/livebook-dev/kino_explorer/pull/82))
- Correctly handles `Time` in filters ([#83](https://github.com/livebook-dev/kino_explorer/pull/83))

## [v0.1.5](https://github.com/livebook-dev/kino_explorer/tree/v0.1.5) (2023-05-11)

### Added

- Queried filters ([#67](https://github.com/livebook-dev/kino_explorer/pull/67))
- Filter by quantile ([#68](https://github.com/livebook-dev/kino_explorer/pull/68))
- Allow any data structure that implements `Table.Reader` ([#75](https://github.com/livebook-dev/kino_explorer/pull/75))
- Allow `categorical` on `pivot_wider` ([#77](https://github.com/livebook-dev/kino_explorer/pull/77))

### Changed

- Allow `summarise` anywhere ([#71](https://github.com/livebook-dev/kino_explorer/pull/71))

### Fixed

- Correctly handles `nil` in summaries ([#72](https://github.com/livebook-dev/kino_explorer/pull/72))
- Correctly handles lazy data frames ([#78](https://github.com/livebook-dev/kino_explorer/pull/78))

## [v0.1.4](https://github.com/livebook-dev/kino_explorer/tree/v0.1.4) (2023-04-04)

### Fixed

- Correctly toggles `summarise` ([#60](https://github.com/livebook-dev/kino_explorer/pull/60))

## [v0.1.3](https://github.com/livebook-dev/kino_explorer/tree/v0.1.3) (2023-04-04)

### Added

- `group_by` and `summarise` operations for Data Transform cell ([#50](https://github.com/livebook-dev/kino_explorer/pull/50))
- Show if a column is in a group on DataTable header ([#53](https://github.com/livebook-dev/kino_explorer/pull/53))
- More aggregations for `summarise` ([#58](https://github.com/livebook-dev/kino_explorer/pull/58))

### Changed

- `pivot_wider` now supports multiple `values_from` ([#47](https://github.com/livebook-dev/kino_explorer/pull/47))

## [v0.1.2](https://github.com/livebook-dev/kino_explorer/tree/v0.1.2) (2023-03-18)

### Changed

- Automatically generates missing requires ([#45](https://github.com/livebook-dev/kino_explorer/pull/45))
- Starts the Data transform cell with only the filter operation ([#46](https://github.com/livebook-dev/kino_explorer/pull/46))

## [v0.1.1](https://github.com/livebook-dev/kino_explorer/tree/v0.1.1) (2023-03-11)

### Fixed

- Correctly toggles `pivot_wider` ([#41](https://github.com/livebook-dev/kino_explorer/pull/41))

## [v0.1.0](https://github.com/livebook-dev/kino_explorer/tree/v0.1.0) (2023-03-07)

Initial release.
