#include <thread>
#include "halley/tools/assets/import_assets_task.h"
#include "halley/tools/assets/check_assets_task.h"
#include "halley/tools/project/project.h"
#include "halley/tools/assets/import_assets_database.h"
#include "halley/resources/resource_data.h"

using namespace Halley;

ImportAssetsTask::ImportAssetsTask(String taskName, ImportAssetsDatabase& db, const AssetImporter& importer, Path assetsPath, Vector<ImportAssetsDatabaseEntry>&& files)
	: EditorTask(taskName, true, true)
	, db(db)
	, importer(importer)
	, assetsPath(assetsPath)
	, files(std::move(files))
{}

void ImportAssetsTask::run()
{
	using namespace std::chrono_literals;
	auto lastSave = std::chrono::steady_clock::now();

	for (size_t i = 0; i < files.size(); ++i) {
		if (isCancelled()) {
			break;
		}

		curFileProgressStart = float(i) / float(files.size());
		curFileProgressEnd = float(i + 1) / float(files.size());
		curFileLabel = files[i].assetId;
		setProgress(curFileProgressStart, curFileLabel);

		try {
			importAsset(files[i]);
			if (isCancelled()) {
				// If this was cancelled, the asset importing might have stopped halfway, so abort without marking it as imported
				break;
			}
			db.markAsImported(files[i]);

			// Check if db needs saving
			auto now = std::chrono::steady_clock::now();
			if (now - lastSave > 1s) {
				db.save();
				lastSave = now;
			}
		} catch (std::exception& e) {
			std::cout << "Error importing asset " << files[i].assetId << ": " << e.what() << std::endl;
		}
	}
	db.save();

	if (!isCancelled()) {
		setProgress(1.0f, "");
	}
}

void ImportAssetsTask::importAsset(ImportAssetsDatabaseEntry& asset)
{
	auto previous = asset.outputFiles;
	auto out = importer.getImporter(asset.assetType).import(asset, assetsPath, [&] (float progress, String label) -> bool
	{
		setProgress(lerp(curFileProgressStart, curFileProgressEnd, progress), curFileLabel + " " + label);
		return !isCancelled();
	});
	asset.outputFiles = out;
	for (auto& f: previous) {
		if (std::find(out.begin(), out.end(), f) == out.end()) {
			// File no longer exists as part of this asset, remove it
			FileSystem::remove(assetsPath / f);
		}
	}
}