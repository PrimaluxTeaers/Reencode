package com.teacers.reencode;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.provider.DocumentsContract;
import android.provider.OpenableColumns;
import android.webkit.MimeTypeMap;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileInputStream;
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
	private static final int REQUEST_OUTPUT_TREE = 0x5245;
	private static final String OUTPUT_PREFS = "reencode_output";
	private static final String KEY_TREE_URI = "tree_uri";
	private static final String KEY_TREE_NAME = "tree_name";

	private MethodChannel.Result pendingOutputResult;

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
