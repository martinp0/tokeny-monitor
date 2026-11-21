# Resources

`model-prices.json` is not stored here. The copy comes from `shared/pricing/model-prices.json`
via `scripts/sync-shared-pricing.sh` (Xcode Cloud runs it in `ci_scripts/ci_post_clone.sh`;
the Xcode schemes run it as a pre-action). It is a real file, not a symlink.
Run the script before `swift test` if this directory has no `model-prices.json` yet.
