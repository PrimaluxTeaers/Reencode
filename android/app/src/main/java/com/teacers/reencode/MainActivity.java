package com.teacers.reencode;

import android.Manifest;
import android.app.Activity;
import android.app.ActivityManager;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.media.MediaFormat;
import android.net.Uri;
import android.os.Build;
import android.provider.DocumentsContract;
import android.provider.MediaStore;
import android.provider.OpenableColumns;
import android.webkit.MimeTypeMap;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
	private static final String OUTPUT_CHANNEL = "reencode/output";
	private static final String PROGRESS_CHANNEL = "reencode/progress";
	private static final String DEVICE_CHANNEL = "reencode/device";
	private static final String GALLERY_CHANNEL = "reencode/gallery";
	private static final int REQUEST_OUTPUT_TREE = 0x5245;
	private static final int REQUEST_NOTIFICATIONS = 0x5246;
	private static final int REQUEST_GALLERY = 0x5247;
	private static final String OUTPUT_PREFS = "reencode_output";
	private static final String KEY_TREE_URI = "tree_uri";
	private static final String KEY_TREE_NAME = "tree_name";

	private MethodChannel.Result pendingOutputResult;
	private MethodChannel.Result pendingGalleryResult;

	@Override
	public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
		super.configureFlutterEngine(flutterEngine);

		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), OUTPUT_CHANNEL)
			.setMethodCallHandler((call, result) -> {
				switch (call.method) {
					case "current":
						result.success(storedTarget());
						break;
					case "choose":
						chooseOutputTree(result);
						break;
					case "clear":
						result.success(clearOutputTree());
						break;
					case "publish":
						Map<?, ?> args = call.arguments instanceof Map ? (Map<?, ?>) call.arguments : null;
						String path = args != null && args.get("path") instanceof String
							? (String) args.get("path")
							: null;
						publishFile(path, result);
						break;
					default:
						result.notImplemented();
				}
			});

		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), GALLERY_CHANNEL)
			.setMethodCallHandler((call, result) -> {
				if ("pickVideo".equals(call.method)) {
					pickGalleryVideo(result);
				} else {
					result.notImplemented();
				}
			});

		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), DEVICE_CHANNEL)
			.setMethodCallHandler((call, result) -> {
				if ("profile".equals(call.method)) {
					result.success(deviceProfile());
				} else {
					result.notImplemented();
				}
			});

		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), PROGRESS_CHANNEL)
			.setMethodCallHandler((call, result) -> {
				Map<?, ?> args = call.arguments instanceof Map ? (Map<?, ?>) call.arguments : null;
				String title = stringArg(args, "title", "Reencode");
				String text = stringArg(args, "text", "");
				int progress = intArg(args, "progress", 0);
				switch (call.method) {
					case "start":
						ensureNotificationPermission();
						ProgressService.start(this, title, text, args != null && Boolean.TRUE.equals(args.get("keepAwake")));
						result.success(true);
						break;
					case "update":
						ProgressService.update(this, title, text, progress);
						result.success(true);
						break;
					case "stop":
						ProgressService.stop(this);
						result.success(true);
						break;
					default:
						result.notImplemented();
				}
			});
	}

	private void pickGalleryVideo(MethodChannel.Result result) {
		if (pendingGalleryResult != null) {
			result.error("busy", "The gallery picker is already open.", null);
			return;
		}
		Intent intent;
		if (Build.VERSION.SDK_INT >= 33) {
			intent = new Intent(MediaStore.ACTION_PICK_IMAGES);
			intent.setType("video/*");
		} else {
			intent = new Intent(Intent.ACTION_GET_CONTENT);
			intent.addCategory(Intent.CATEGORY_OPENABLE);
			intent.setType("video/*");
		}
		pendingGalleryResult = result;
		try {
			startActivityForResult(intent, REQUEST_GALLERY);
		} catch (Exception first) {
			pendingGalleryResult = null;
			try {
				Intent fallback = new Intent(Intent.ACTION_GET_CONTENT);
				fallback.addCategory(Intent.CATEGORY_OPENABLE);
				fallback.setType("video/*");
				pendingGalleryResult = result;
				startActivityForResult(fallback, REQUEST_GALLERY);
			} catch (Exception second) {
				pendingGalleryResult = null;
				result.error("picker", second.getMessage(), null);
			}
		}
	}

	private void finalGallery(int resultCode, Intent data) {
		MethodChannel.Result result = pendingGalleryResult;
		pendingGalleryResult = null;
		if (result == null) return;
		if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
			result.success(null);
			return;
		}
		Uri uri = data.getData();
		try {
			String name = displayName(uri);
			if (name == null || name.isEmpty()) name = "gallery-video.mp4";
			File folder = new File(getCacheDir(), "gallery");
			if (!folder.exists() && !folder.mkdirs()) {
				result.error("cache", "Could not create the cache folder.", null);
				return;
			}
			File target = new File(folder, System.currentTimeMillis() + "-" + name);
			try (InputStream in = getContentResolver().openInputStream(uri);
				OutputStream out = new FileOutputStream(target)) {
				if (in == null) throw new IOException("Empty gallery URI");
				byte[] buffer = new byte[65536];
				int read;
				while ((read = in.read(buffer)) != -1) out.write(buffer, 0, read);
			}
			result.success(target.getAbsolutePath());
		} catch (Exception error) {
			result.error("copy", error.getMessage(), null);
		}
	}

	private Map<String, Object> deviceProfile() {
		Map<String, Object> map = new HashMap<>();
		map.put("platform", "android");
		map.put("sdk", Build.VERSION.SDK_INT);
		map.put("release", Build.VERSION.RELEASE);
		map.put("manufacturer", safe(Build.MANUFACTURER));
		map.put("brand", safe(Build.BRAND));
		map.put("model", safe(Build.MODEL));
		map.put("hardware", safe(Build.HARDWARE));
		map.put("board", safe(Build.BOARD));
		String socModel = "";
		String socManufacturer = "";
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			socModel = safe(Build.SOC_MODEL);
			socManufacturer = safe(Build.SOC_MANUFACTURER);
		}
		map.put("socModel", socModel);
		map.put("socManufacturer", socManufacturer);
		map.put("gpu", inferGpu(socModel + " " + Build.HARDWARE + " " + Build.BOARD));
		map.put("cores", Runtime.getRuntime().availableProcessors());
		ActivityManager manager = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
		ActivityManager.MemoryInfo info = new ActivityManager.MemoryInfo();
		manager.getMemoryInfo(info);
		map.put("totalRamMb", info.totalMem / 1048576L);
		map.put("lowRam", info.lowMemory);
		boolean av1Decode = false;
		boolean av1Encode = false;
		boolean avcEncode = false;
		boolean hevcEncode = false;
		try {
			MediaCodecList list = new MediaCodecList(MediaCodecList.REGULAR_CODECS);
			for (MediaCodecInfo codec : list.getCodecInfos()) {
				for (String type : codec.getSupportedTypes()) {
					if (MediaFormat.MIMETYPE_VIDEO_AV1.equals(type)) {
						if (codec.isEncoder()) av1Encode = true; else av1Decode = true;
					} else if (MediaFormat.MIMETYPE_VIDEO_AVC.equals(type) && codec.isEncoder()) {
						avcEncode = true;
					} else if ("video/hevc".equals(type) && codec.isEncoder()) {
						hevcEncode = true;
					}
				}
			}
		} catch (Throwable ignored) {
			// A device that refuses the codec list still gets the rest of the profile.
		}
		map.put("av1Decode", av1Decode);
		map.put("av1Encode", av1Encode);
		map.put("avcEncode", avcEncode);
		map.put("hevcEncode", hevcEncode);
		return map;
	}

	private String safe(String value) {
		return value == null ? "" : value;
	}

	private String inferGpu(String raw) {
		String lower = raw.toLowerCase();
		if (lower.contains("9600")) return "Mali-G2 Ultra NX (Dimensity 9600)";
		if (lower.contains("9400")) return "Mali-G925 (Dimensity 9400)";
		if (lower.contains("9300")) return "Mali-G720 (Dimensity 9300)";
		if (lower.contains("8500") || lower.contains("8400")) return "Mali-G720 (Dimensity 8000 series)";
		if (lower.contains("8 elite") || lower.contains("sm8750") || lower.contains("sm8850")) return "Adreno 8xx (Snapdragon 8 Elite)";
		if (lower.contains("sm7750") || lower.contains("7 gen 4")) return "Adreno 722 (Snapdragon 7 Gen 4)";
		if (lower.contains("mali")) return "Mali";
		if (lower.contains("adreno")) return "Adreno";
		return "Unknown GPU";
	}

	private String stringArg(Map<?, ?> args, String key, String fallback) {
		if (args == null) return fallback;
		Object value = args.get(key);
		return value instanceof String ? (String) value : fallback;
	}

	private int intArg(Map<?, ?> args, String key, int fallback) {
		if (args == null) return fallback;
		Object value = args.get(key);
		return value instanceof Number ? ((Number) value).intValue() : fallback;
	}

	private void ensureNotificationPermission() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return;
		if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
			== PackageManager.PERMISSION_GRANTED) return;
		requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQUEST_NOTIFICATIONS);
	}

	private SharedPreferences outputPrefs() {
		return getSharedPreferences(OUTPUT_PREFS, Context.MODE_PRIVATE);
	}

	private Map<String, Object> storedTarget() {
		SharedPreferences prefs = outputPrefs();
		String uri = prefs.getString(KEY_TREE_URI, null);
		if (uri == null || uri.isEmpty()) return null;
		String name = prefs.getString(KEY_TREE_NAME, null);
		if (name == null || name.isEmpty()) name = displayName(Uri.parse(uri));
		return targetMap(uri, name);
	}

	private Map<String, Object> targetMap(String uri, String name) {
		Map<String, Object> map = new HashMap<>();
		map.put("uri", uri);
		map.put("name", name == null || name.isEmpty() ? "Output folder" : name);
		return map;
	}

	private void chooseOutputTree(MethodChannel.Result result) {
		if (pendingOutputResult != null) {
			result.error("busy", "The folder picker is already open.", null);
			return;
		}
		Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
		intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
			| Intent.FLAG_GRANT_WRITE_URI_PERMISSION
			| Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
			| Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
		pendingOutputResult = result;
		try {
			startActivityForResult(intent, REQUEST_OUTPUT_TREE);
		} catch (Exception e) {
			pendingOutputResult = null;
			result.error("picker", e.getMessage(), null);
		}
	}

	@Override
	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		super.onActivityResult(requestCode, resultCode, data);
		if (requestCode == REQUEST_GALLERY) {
			finalGallery(resultCode, data);
			return;
		}
		if (requestCode != REQUEST_OUTPUT_TREE) return;
		MethodChannel.Result result = pendingOutputResult;
		pendingOutputResult = null;
		if (result == null) return;
		if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
			result.success(null);
			return;
		}
		Uri tree = data.getData();
		int flags = data.getFlags()
			& (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
		try {
			getContentResolver().takePersistableUriPermission(tree, flags);
		} catch (SecurityException e) {
			result.error("permission", "The system did not keep write access to this folder.", null);
			return;
		}
		String name = displayName(tree);
		outputPrefs().edit()
			.putString(KEY_TREE_URI, tree.toString())
			.putString(KEY_TREE_NAME, name)
			.apply();
		result.success(targetMap(tree.toString(), name));
	}

	private boolean clearOutputTree() {
		String stored = outputPrefs().getString(KEY_TREE_URI, null);
		if (stored != null && !stored.isEmpty()) {
			Uri tree = Uri.parse(stored);
			try {
				getContentResolver().releasePersistableUriPermission(
					tree,
					Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
				);
			} catch (SecurityException ignored) {
				// The grant may already be gone; removing the preference is enough.
			}
		}
		outputPrefs().edit().remove(KEY_TREE_URI).remove(KEY_TREE_NAME).apply();
		return true;
	}

	private void publishFile(String path, MethodChannel.Result result) {
		if (path == null || path.isEmpty()) {
			result.error("path", "Missing local file path.", null);
			return;
		}
		Map<String, Object> target = storedTarget();
		if (target == null) {
			result.error("folder", "No output folder is selected.", null);
			return;
		}
		File source = new File(path);
		if (!source.isFile()) {
			result.error("file", "The converted file is gone.", null);
			return;
		}
		Uri tree = Uri.parse((String) target.get("uri"));
		Uri parent = treeDocumentUri(tree);
		Uri destination = null;
		try {
			String name = uniqueName(tree, parent, source.getName());
			String mime = mimeFor(name);
			destination = DocumentsContract.createDocument(
				getContentResolver(), parent, mime, name
			);
			if (destination == null) {
				result.error("create", "The folder refused a new file.", null);
				return;
			}
			ContentResolver resolver = getContentResolver();
			try (InputStream in = new FileInputStream(source);
				 OutputStream out = resolver.openOutputStream(destination)) {
				if (out == null) throw new IllegalStateException("No write stream.");
				byte[] buffer = new byte[8192];
				int read;
				while ((read = in.read(buffer)) != -1) {
					out.write(buffer, 0, read);
				}
				out.flush();
			}
			String writtenName = displayName(destination);
			Map<String, Object> map = new HashMap<>();
			map.put("uri", destination.toString());
			map.put("name", writtenName);
			result.success(map);
		} catch (Exception e) {
			if (destination != null) {
				try {
					DocumentsContract.deleteDocument(getContentResolver(), destination);
				} catch (Exception ignored) {}
			}
			result.error("copy", e.getMessage(), null);
		}
	}

	private Uri treeDocumentUri(Uri tree) {
		return DocumentsContract.buildDocumentUriUsingTree(
			tree, DocumentsContract.getTreeDocumentId(tree)
		);
	}

	private String displayName(Uri uri) {
		try {
			Uri document = DocumentsContract.isDocumentUri(this, uri)
				? uri
				: DocumentsContract.buildDocumentUriUsingTree(
					uri, DocumentsContract.getTreeDocumentId(uri)
				);
			try (Cursor cursor = getContentResolver().query(
				document, new String[]{OpenableColumns.DISPLAY_NAME},
				null, null, null
			)) {
				if (cursor != null && cursor.moveToFirst()) {
					int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
					if (index >= 0) {
						String value = cursor.getString(index);
						if (value != null && !value.trim().isEmpty()) return value.trim();
					}
				}
			}
		} catch (Exception ignored) {}
		String last = uri.getLastPathSegment();
		return last == null || last.isEmpty() ? "Output folder" : last;
	}

	private String uniqueName(Uri tree, Uri parent, String name) {
		Set<String> existing = new HashSet<>();
		Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(
			tree, DocumentsContract.getTreeDocumentId(tree)
		);
		try (Cursor cursor = getContentResolver().query(
			children, new String[]{DocumentsContract.Document.COLUMN_DISPLAY_NAME},
			null, null, null
		)) {
			if (cursor != null) {
				while (cursor.moveToNext()) {
					String child = cursor.getString(0);
					if (child != null) existing.add(child.toLowerCase());
				}
			}
		} catch (Exception ignored) {}
		if (!existing.contains(name.toLowerCase())) return name;
		int dot = name.lastIndexOf('.');
		String stem = dot > 0 ? name.substring(0, dot) : name;
		String extension = dot > 0 ? name.substring(dot) : "";
		for (int n = 2; n < 10000; n++) {
			String candidate = stem + " (" + n + ")" + extension;
			if (!existing.contains(candidate.toLowerCase())) return candidate;
		}
		return stem + " (" + System.currentTimeMillis() + ")" + extension;
	}

	private String mimeFor(String name) {
		int dot = name.lastIndexOf('.');
		if (dot > 0) {
			String extension = name.substring(dot + 1).toLowerCase();
			String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
			if (mime != null && !mime.isEmpty()) return mime;
		}
		return "application/octet-stream";
	}
}
