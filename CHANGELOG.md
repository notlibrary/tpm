# Changelog

## [Unreleased]

### Added
- Added support for reversing toothpaste lists.
- Added Polish localization.

### Documentation
- Documented reverse-list support.

### Maintenance
- Updated list ordering and fixed a memory leak.
- Adopted the Conventional Commits format.

## [0.7.5] - 2026-08-24

### Fixed
- Fixed remaining issues and improved the safer `_s` string functions.
- Fixed file handling and related size warnings.

## [0.7.4] - 2026-08-10

### Added
- Added brushing-coverage statistics and frontend support.
- Added a default template and updated documentation.

### Fixed
- Improved WASM/WASI builds and resolved related warnings.
- Fixed coverage, localization, frontend structure, and message handling.

### Maintenance
- Updated build, release, and manifest files.

## [0.7.3] - 2026-08-03

### Added
- Added a new driver and expanded the backend/frontend integration.
- Added database installation, registration, login, and logout support.
- Added static analysis, sanitizers, and additional build checks.

### Fixed
- Improved WASM builds, compiler warnings, tests, and validation.

## [0.7.2] - 2026-07-20

### Added
- Added the toothpaste database administration interface.
- Added backend database support and PostgreSQL access.
- Improved the frontend, localization preparation, and recommendations.

## [0.7.1] - 2026-07-13

### Added
- Added initial frontend functionality and repository/application links.
- Expanded localization support and gettext integration.

### Fixed
- Improved locale handling, WASM builds, messages, and build workflows.

## [0.7.0] - 2026-07-07

### Added
- Added broad internationalization support and translation files.
- Added localized user messages and improved locale initialization.
- Improved terminal prompts and build automation.

### Fixed
- Removed the remaining `system("pause")` usage.
- Improved localization and workflow handling.

## [0.6.9] - 2026-07-03

### Added
- Added locale switching and more precise localization initialization.
- Improved the installer, workflow, and build configuration.
- Added additional localization infrastructure.

### Fixed
- Cleaned up installer, build, and localization issues.

## [0.6.8] - 2026-06-25

### Added
- Began the internationalization effort with multiple languages.
- Added dental-formula support and improved distribution preparation.
- Added early locale initialization.

### Fixed
- Cleaned the build and related distribution files.

## [0.6.7] - 2026-06-18

### Refactored
- Reworked the internal context and public API.
- Removed unnecessary global/static state and improved memory handling.
- Added integer error codes and strengthened tests.

### Fixed
- Resolved compiler warnings, crashes, and test failures.

## [0.6.6] - 2026-06-12

### Added
- Added enhanced toothbrush support and a toothbrush-to-CSV mode.
- Improved linked-list memory management and template handling.

### Fixed
- Improved configuration validation, quiet mode, and memory checks.

## [0.6.5] - 2026-06-09

### Improved
- Prepared the project for the next release and improved templating wildcard handling.

## [0.6.4] - 2026-06-03

### Added
- Added the templater test version and expanded its documentation.
- Improved quiet mode and installer options.

### Fixed
- Cleaned up memory handling, logic, and compiler warnings.

## [0.6.3] - 2026-05-30

### Added
- Added a larger automated test suite and additional edge-case tests.
- Added memory, file-loading, and PRNG tests.
- Improved Autotools support and string handling.

### Fixed
- Eliminated memory leaks and improved Valgrind cleanliness.
- Fixed null-pointer, division-by-zero, getopt, and string truncation issues.

## [0.6.2] - 2026-05-25

### Added
- Added an MSI installer using WiX.
- Added deeper project analysis and improved documentation.
- Added F3 hotkey support and installer branding.

### Maintenance
- Improved distribution packaging and build configuration.

## [0.6.1] - 2026-05-19

### Improved
- Continued WASM build work and cleaned up compiler warnings and typos.

## [0.6.0] - 2026-05-18

### Added
- Added installed headers to distributions.
- Added `config.h` support and installation improvements.

## [0.5.18] - 2026-05-18

### Maintenance
- Prepared the release package.

## [0.5.17] - 2026-05-18

### Improved
- Simplified Autotools usage and improved source tarballs.
- Continued work on portable builds.

## [0.5.16] - 2026-05-16

### Maintenance
- Improved release tag automation.

## [0.5.15] - 2026-05-16

### Maintenance
- Improved the OS release process.

## [0.5.14] - 2026-05-16

### Maintenance
- Prepared the release.

## [0.5.13] - 2026-05-16

### Improved
- Improved terminal-size handling and documentation.
- Added links for action runners and refined release handling.

## [0.5.12] - 2026-05-15

### Added
- Added username handling, fake statistics, and wasted-tube calculations.
- Improved output sizing and documentation.

## [0.5.11] - 2026-05-12

### Added
- Added CSV import/export and database schema support.
- Added scheduled brushing tests and a fake-statistics option.
- Added PowerShell command support.

### Fixed
- Improved timestamp handling and CSV mode reliability.

## [0.5.10] - 2026-05-09

### Added
- Improved linked-list payload initialization.

## [0.5.9] - 2026-05-05

### Improved
- Expanded usage examples and toothpaste-listing documentation.
- Improved WASM compiler detection and large-line handling.

## [0.5.8] - 2026-05-02

### Fixed
- Improved variable initialization and compiler warning handling.

## [0.5.7] - 2026-05-01

### Improved
- Added minor usability and code improvements.

## [0.5.6] - 2026-04-30

### Improved
- Improved formatting and minor implementation details.

## [0.5.5] - 2026-04-29

### Improved
- Improved string handling and corrected minor issues.

## [0.5.4] - 2026-04-28

### Added
- Expanded documentation for toothpaste types and shell usage.
- Extracted user-facing and error messages.

## [0.5.3] - 2026-04-26

### Added
- Added CSV mode and toothpaste-type support.
- Improved CSV documentation and formatting.

## [0.5.2] - 2026-04-25

### Added
- Expanded calculation and version-reporting functionality.
- Improved compiler/version information and exit handling.

## [0.5.1] - 2026-04-24

### Maintenance
- Prepared the release with minor improvements.

## [0.5.0] - 2026-04-23

### Added
- Improved toothpaste volume and usage estimation.
- Added support for multiple tubes of the same brand.
- Added clearer output and source information.

### Improved
- Expanded documentation and handling of uppercase brand names.

## [0.4.11] - 2026-04-21

### Added
- Added automatic attachment after login.
- Expanded project documentation and messaging.

## [0.4.10] - 2026-04-18

### Added
- Improved cron-job support and documented multiple scheduling methods.

## [0.4.9] - 2026-04-16

### Added
- Added dental-formula support such as `2-2-2-2`.
- Documented the new formula handling.

### Fixed
- Fixed memory leaks and null-pointer issues.

## [0.4.8] - 2026-04-14

### Improved
- Improved portability around `time_t` differences between systems.

## [0.4.7] - 2026-04-13

### Improved
- Expanded the manual and README documentation.
- Improved command-line options and formatting.

## [0.4.6] - 2026-04-10

### Added
- Added AI-based toothpaste-picking documentation.
- Improved configuration, cleanup, release workflows, and documentation.

### Fixed
- Improved compiler warnings and various small issues.

## [0.4.5] - 2026-03-28

### Added
- Added quoted-string support in configuration files.
- Added recursive configuration loading and new configuration options.

### Refactored
- Simplified configuration and utility code and improved validation.

## [0.4.4] - 2026-03-21

### Added
- Added configurable toothpaste paths and improved default values.
- Added architecture markers and expanded distribution support.

### Refactored
- Simplified core logic and cleanup routines.

## [0.4.3] - 2026-03-14

### Maintenance
- Prepared the release.

## [0.4.2] - 2026-03-14

### Maintenance
- Updated versioning and distribution metadata.

## [0.0.9] - 2026-03-14

### Maintenance
- Prepared the release.

## [0.0.8] - 2026-03-14

### Maintenance
- Prepared the release.

## [0.0.7] - 2026-03-14

### Maintenance
- Prepared the release.

## [0.0.6] - 2026-03-14

### Maintenance
- Prepared the release.

## [0.0.5] - 2026-03-14

### Maintenance
- Prepared the release.

## [0.0.4] - 2026-03-14

### Maintenance
- Prepared the release.

## [0.0.3] - 2026-03-14

### Maintenance
- Prepared the release.

## [0.0.2] - 2026-03-14

### Maintenance
- Prepared the release.

## [0.0.1] - 2026-03-14

### Added
- Introduced the initial toothpaste selection API.
- Added JSON, CSV, SQL, random, index, and brand-based selection.
- Added configuration-file support and command-line options.
- Added username handling and file output.
- Added initial Makefiles, documentation, and release infrastructure.

### Improved
- Added rating, weight, toothpaste type, and usage constraints.
- Added configuration recursion limits and safer parsing.
- Improved memory management, refactoring, and output handling.

### Fixed
- Fixed the initial Makefile and parser issues.
