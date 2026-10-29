package com.moodmusic.local_media;

import android.content.Context;
import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.webkit.MimeTypeMap;
import android.provider.DocumentsContract;
import java.io.FileInputStream;
import java.io.OutputStream;
import java.util.Locale;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public final class MoodMusicLocalMediaPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, ActivityResultListener {
    private static final int EXPORT_REQUEST = 48721;
    private Context context;
    private ActivityPluginBinding activityBinding;
    private MethodChannel.Result exportResult;
    private File exportSource;
    private boolean exportCopying;
    private MethodChannel channel;
    @Override public void onAttachedToActivity(ActivityPluginBinding binding) {
        activityBinding = binding;
        binding.addActivityResultListener(this);
    }
    private void detachActivity() {
        if (activityBinding != null) activityBinding.removeActivityResultListener(this);
        activityBinding = null;
    }
    @Override public void onDetachedFromActivityForConfigChanges() { detachActivity(); }
    @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }
    @Override public void onDetachedFromActivity() {
        detachActivity();
        finishExport(false, "Se cerró la pantalla de exportación.");
    }
    private void finishExport(boolean saved, String error) {
        MethodChannel.Result pending = exportResult;
        exportResult = null;
        exportSource = null;
        exportCopying = false;
        if (pending == null) return;
        if (error == null) pending.success(saved);
        else pending.error("export", error, null);
    }
    private void beginExport(MethodCall call, MethodChannel.Result result) {
        if (activityBinding == null) { result.error("export", "No se puede abrir el selector de destino.", null); return; }
        if (exportResult != null) { result.error("busy", "Ya hay una exportación en curso.", null); return; }
        try {
            String path = call.argument("path");
            String name = call.argument("name");
            if (path == null) throw new IOException("Selecciona un audio.");
            File source = new File(path).getCanonicalFile();
            String root = new File(context.getApplicationInfo().dataDir).getCanonicalPath() + File.separator;
            if (!source.getPath().startsWith(root) || !source.isFile()) {
                throw new IOException("Solo puedes exportar audios guardados en tu biblioteca.");
            }
            String filename = source.getName();
            int dot = filename.lastIndexOf('.');
            if (dot < 0) throw new IOException("El audio no tiene una extensión válida.");
            String extension = filename.substring(dot + 1).toLowerCase(Locale.ROOT);
            if (!extension.matches("mp3|m4a|aac|wav|ogg|flac")) {
                throw new IOException("El formato del audio no es compatible.");
            }
            String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
            String title = name == null ? "MoodMusic" : name.replaceAll("[^a-zA-Z0-9 ._()áéíóúÁÉÍÓÚñÑ-]", "_").trim();
            if (title.isEmpty()) title = "MoodMusic";
            if (title.length() > 100) title = title.substring(0, 100);
            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType(mime == null ? "audio/*" : mime);
            intent.putExtra(Intent.EXTRA_TITLE, title + "." + extension);
            exportResult = result;
            exportSource = source;
            activityBinding.getActivity().startActivityForResult(intent, EXPORT_REQUEST);
        } catch (Exception error) {
            if (exportResult == result) finishExport(false, "No se pudo abrir el destino del audio.");
            else result.error("export", error.getMessage(), null);
        }
    }
    @Override public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != EXPORT_REQUEST || exportResult == null) return false;
        if (exportCopying) return true;
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            finishExport(false, null);
            return true;
        }
        exportCopying = true;
        final Uri destination = data.getData();
        final File source = exportSource;
        final MethodChannel.Result pending = exportResult;
        final Context exportContext = context;
        worker.execute(() -> {
            String error = null;
            try (FileInputStream input = new FileInputStream(source);
                 OutputStream output = exportContext.getContentResolver().openOutputStream(destination, "w")) {
                if (output == null) throw new IOException("No se pudo abrir el destino.");
                byte[] buffer = new byte[65536];
                int count;
                while ((count = input.read(buffer)) != -1) {
                    if (Thread.currentThread().isInterrupted()) throw new IOException("Exportación cancelada.");
                    output.write(buffer, 0, count);
                }
                output.flush();
            } catch (Exception failure) {
                error = "No se pudo exportar el audio. Revisa el espacio disponible y el destino.";
                try { DocumentsContract.deleteDocument(exportContext.getContentResolver(), destination); }
                catch (Exception ignored) { }
            }
            final String problem = error;
            main.post(() -> {
                // A detached session must not complete a later export request.
                if (exportResult == pending) finishExport(problem == null, problem);
            });
        });
        return true;
    }
    private File cache;
    private ExecutorService worker;
    private final AtomicBoolean busy = new AtomicBoolean(false);
    private volatile boolean attached;
    private final Handler main = new Handler(Looper.getMainLooper());
    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        cache = context.getCacheDir();
        worker = Executors.newSingleThreadExecutor();
        attached = true;
        channel = new MethodChannel(binding.getBinaryMessenger(), "moodmusic/local_media");
        channel.setMethodCallHandler(this);
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        attached = false;
        finishExport(false, "Exportación cancelada.");
        channel.setMethodCallHandler(null);
        worker.shutdownNow();
    }
    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("exportAudio")) { beginExport(call, result); return; }
        if (!call.method.equals("extractAudio")) { result.notImplemented(); return; }
        String path = call.argument("path");
        if (path == null) { result.error("input", "Selecciona un video.", null); return; }
        if (!busy.compareAndSet(false, true)) { result.error("busy", "Ya se está procesando un video.", null); return; }
        worker.execute(() -> {
            try {
                File output = extract(path);
                main.post(() -> {
                    if (attached) result.success(output.getAbsolutePath());
                    else { output.delete(); output.getParentFile().delete(); }
                });
            } catch (Exception error) {
                final String message = error instanceof IOException ? error.getMessage() : "No se pudo procesar este video. Prueba un MP4 con sonido AAC.";
                main.post(() -> { if (attached) result.error("extract", message, null); });
            } finally { busy.set(false); }
        });
    }
    private File extract(String path) throws Exception {
        File input = new File(path).getCanonicalFile();
        String root = cache.getCanonicalPath() + File.separator;
        if (!input.getPath().startsWith(root) || !input.isFile()) throw new IOException("No se pudo acceder al video seleccionado.");
        if (input.length() == 0 || input.length() > 300L * 1024 * 1024) throw new IOException("El video debe pesar entre 1 byte y 300 MB.");
        File directory = new File(cache, "mood_import_" + UUID.randomUUID());
        if (!directory.mkdir()) throw new IOException("No hay espacio para preparar el audio.");
        File output = new File(directory, "extracted.m4a");
        MediaExtractor extractor = new MediaExtractor();
        MediaMuxer muxer = null;
        boolean started = false, success = false;
        try {
            extractor.setDataSource(input.getAbsolutePath());
            int selected = -1;
            boolean hasAudio = false;
            MediaFormat format = null;
            for (int i = 0; i < extractor.getTrackCount(); i++) {
                MediaFormat candidate = extractor.getTrackFormat(i);
                String mime = candidate.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) hasAudio = true;
                if ("audio/mp4a-latm".equals(mime)) { selected = i; format = candidate; break; }
            }
            if (!hasAudio) throw new IOException("Este video no contiene una pista de sonido.");
            if (selected < 0) throw new IOException("El sonido de este video no es AAC. Prueba un MP4 con audio AAC o importa un archivo de audio.");
            extractor.selectTrack(selected);
            muxer = new MediaMuxer(output.getAbsolutePath(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            int track = muxer.addTrack(format);
            muxer.start(); started = true;
            ByteBuffer buffer = ByteBuffer.allocateDirect(2 * 1024 * 1024);
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            long first = -1, previous = -1, bytes = 0;
            int samples = 0;
            while (extractor.getSampleTrackIndex() >= 0) {
                if (Thread.currentThread().isInterrupted()) throw new IOException("Extracción cancelada.");
                int flags = extractor.getSampleFlags();
                if ((flags & MediaExtractor.SAMPLE_FLAG_ENCRYPTED) != 0) throw new IOException("No se pueden importar videos protegidos.");
                if (Build.VERSION.SDK_INT >= 28) {
                    long needed = extractor.getSampleSize();
                    if (needed > 8 * 1024 * 1024) throw new IOException("La pista de audio no es compatible.");
                    if (needed > buffer.capacity()) buffer = ByteBuffer.allocateDirect((int) needed);
                }
                buffer.clear();
                int size = extractor.readSampleData(buffer, 0);
                if (size < 0) break;
                long time = extractor.getSampleTime();
                if (first < 0) first = time;
                long timestamp = Math.max(0, time - first);
                if (timestamp < previous) throw new IOException("El video contiene tiempos de audio inválidos.");
                previous = timestamp;
                bytes += size;
                if (bytes > 99L * 1024 * 1024) throw new IOException("El audio extraído supera el límite de 100 MB.");
                info.set(0, size, timestamp, (flags & MediaExtractor.SAMPLE_FLAG_SYNC) != 0 ? MediaCodec.BUFFER_FLAG_KEY_FRAME : 0);
                muxer.writeSampleData(track, buffer, info);
                samples++;
                if (!extractor.advance()) break;
            }
            if (samples == 0) throw new IOException("La pista de sonido está vacía.");
            muxer.stop(); started = false;
            if (output.length() > 100L * 1024 * 1024) throw new IOException("El audio extraído supera 100 MB.");
            success = true;
            return output;
        } finally {
            extractor.release();
            if (muxer != null) {
                if (started) { try { muxer.stop(); } catch (RuntimeException ignored) {} }
                try { muxer.release(); } catch (RuntimeException ignored) {}
            }
            if (!success) { output.delete(); directory.delete(); }
        }
    }
}
