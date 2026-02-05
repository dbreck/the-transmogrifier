# Release Process

Steps to release a new version of The Transmogrifier.

## 1. Prepare the release

```bash
# Create a release branch
git checkout master && git pull
git checkout -b release/x.y.z

# Bump version everywhere
./scripts/bump-version.sh x.y.z

# Review changes
git diff
```

## 2. Update the changelog

Edit `website/src/pages/changelog.astro` with the new version's changes.

## 3. Commit and open a PR

```bash
git add -A
git commit -m "Bump version to x.y.z"
git push -u origin release/x.y.z
gh pr create --title "Release x.y.z" --body "Version bump and changelog update"
```

Wait for CI to pass (website build + app compile check). Cloudflare Pages will deploy a preview — verify it looks right.

## 4. Merge

Squash-merge the PR to `master`. Delete the branch.

## 5. Build and submit to App Store

1. Pull `master`: `git checkout master && git pull`
2. Open Xcode: `open ImageProcessingApp.xcodeproj`
3. Product > Archive
4. Distribute App > App Store Connect > Upload

## 6. Build DMG for direct distribution

```bash
./build-dmg.sh x.y.z --sign --notarize
```

(Requires Developer ID Application certificate and notarization credentials.)

## 7. Tag and create GitHub Release

```bash
git tag -a vx.y.z -m "vx.y.z"
git push origin vx.y.z
```

This triggers the release workflow, which creates a **draft** GitHub Release with auto-generated notes.

Go to [GitHub Releases](https://github.com/dbreck/the-transmogrifier/releases), edit the draft:
- Attach the notarized DMG
- Review the release notes
- Publish

## Quick reference

| What | Command |
|------|---------|
| Bump version | `./scripts/bump-version.sh x.y.z` |
| Build DMG | `./build-dmg.sh x.y.z --sign --notarize` |
| Tag release | `git tag -a vx.y.z -m "vx.y.z" && git push origin vx.y.z` |
