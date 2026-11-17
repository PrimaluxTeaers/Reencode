package com.teacers.reencode;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;

/**
 * Keeps the conversion process alive while the app is in the background and
 * mirrors the current file/progress into a low-priority notification.
 */
public class ProgressService extends Service {
	public static final String CHANNEL_ID = "reencode_conversion";
	public static final int NOTIFICATION_ID = 0x5245;
	public static final String ACTION_START = "com.teacers.reencode.progress.START";
	public static final String ACTION_UPDATE = "com.teacers.reencode.progress.UPDATE";
	public static final String ACTION_STOP = "com.teacers.reencode.progress.STOP";

	private NotificationManager manager;
	private PowerManager.WakeLock wakeLock;

	@Override
	public void onCreate() {
		super.onCreate();
		manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			NotificationChannel channel = new NotificationChannel(
				CHANNEL_ID,
				"Conversion progress",
				NotificationManager.IMPORTANCE_LOW
			);
			channel.setDescription("Shows which file Reencode is working on.");
			channel.setShowBadge(false);
			manager.createNotificationChannel(channel);
		}
	}

	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {
		if (intent == null || ACTION_STOP.equals(intent.getAction())) {
			stopForegroundCompat();
			stopSelf();
			return START_NOT_STICKY;
		}

		String title = intent.getStringExtra("title");
		String text = intent.getStringExtra("text");
		int progress = intent.getIntExtra("progress", 0);
		boolean indeterminate = intent.getBooleanExtra("indeterminate", false);
		if (title == null || title.isEmpty()) title = "Reencode";
		if (text == null) text = "";

		Notification notification = build(title, text, progress, indeterminate);
		startForeground(NOTIFICATION_ID, notification);
		if (intent.getBooleanExtra("keepAwake", false)) acquireWakeLock();
		return START_NOT_STICKY;
	}

	@SuppressWarnings("deprecation")
	private Notification build(String title, String text, int progress, boolean indeterminate) {
		Intent open = new Intent(this, MainActivity.class);
		open.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
		PendingIntent pending = PendingIntent.getActivity(
			this,
			0,
			open,
			PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
		);

		Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
			? new Notification.Builder(this, CHANNEL_ID)
			: new Notification.Builder(this);
		return builder
			.setSmallIcon(android.R.drawable.stat_sys_download)
			.setContentTitle(title)
			.setContentText(text)
			.setContentIntent(pending)
			.setOngoing(true)
			.setOnlyAlertOnce(true)
			.setPriority(Notification.PRIORITY_LOW)
			.setProgress(100, Math.max(0, Math.min(100, progress)), indeterminate)
			.build();
	}

	@SuppressWarnings("deprecation")
	private void acquireWakeLock() {
		if (wakeLock != null && wakeLock.isHeld()) return;
		PowerManager power = (PowerManager) getSystemService(Context.POWER_SERVICE);
		wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Reencode:convert");
		wakeLock.setReferenceCounted(false);
		wakeLock.acquire(10 * 60 * 1000L);
	}

	private void releaseWakeLock() {
		if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
		wakeLock = null;
	}

	private void stopForegroundCompat() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
			stopForeground(STOP_FOREGROUND_REMOVE);
		} else {
			stopForeground(true);
		}
		releaseWakeLock();
		manager.cancel(NOTIFICATION_ID);
	}

	@Override
	public IBinder onBind(Intent intent) {
		return null;
	}

	static void start(Context context, String title, String text, boolean keepAwake) {
		Intent intent = new Intent(context, ProgressService.class)
			.setAction(ACTION_START)
			.putExtra("title", title)
			.putExtra("text", text)
			.putExtra("progress", 0)
			.putExtra("keepAwake", keepAwake)
			.putExtra("indeterminate", true);
		startServiceCompat(context, intent);
	}

	static void update(Context context, String title, String text, int progress) {
		Intent intent = new Intent(context, ProgressService.class)
			.setAction(ACTION_UPDATE)
			.putExtra("title", title)
			.putExtra("text", text)
			.putExtra("progress", progress)
			.putExtra("indeterminate", false);
		startServiceCompat(context, intent);
	}

	static void stop(Context context) {
		Intent intent = new Intent(context, ProgressService.class).setAction(ACTION_STOP);
		context.startService(intent);
	}

	private static void startServiceCompat(Context context, Intent intent) {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			context.startForegroundService(intent);
		} else {
			context.startService(intent);
		}
	}
}
