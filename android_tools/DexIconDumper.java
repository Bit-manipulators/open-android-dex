package com.opendex.tools;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.os.Looper;
import java.io.File;
import java.io.FileOutputStream;
import java.lang.reflect.Method;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class DexIconDumper {
    public static void main(String[] args) {
        try {
            Looper.prepareMainLooper();

            // Reflection to obtain system context without being an APK
            PackageManager pm = null;
            try {
                Class<?> atClass = Class.forName("android.app.ActivityThread");
                Method systemMainMethod = atClass.getMethod("systemMain");
                Object activityThread = systemMainMethod.invoke(null);
                if (activityThread != null) {
                    Method getSysContextMethod = atClass.getMethod("getSystemContext");
                    Context context = (Context) getSysContextMethod.invoke(activityThread);
                    if (context != null) {
                        pm = context.getPackageManager();
                    }
                }
            } catch (Throwable t1) {
                try {
                    Class<?> atClass = Class.forName("android.app.ActivityThread");
                    Method currentMethod = atClass.getMethod("currentActivityThread");
                    Object activityThread = currentMethod.invoke(null);
                    if (activityThread != null) {
                        Method getSysContextMethod = atClass.getMethod("getSystemContext");
                        Context context = (Context) getSysContextMethod.invoke(activityThread);
                        if (context != null) {
                            pm = context.getPackageManager();
                        }
                    }
                } catch (Throwable t2) {
                    // Context not available in this shell environment
                }
            }

            if (pm == null) {
                System.out.println("DONE:0");
                return;
            }

            String outputDirPath = args.length > 0 ? args[0] : "/data/local/tmp/opendex_icons";
            File outDir = new File(outputDirPath);
            if (!outDir.exists()) {
                outDir.mkdirs();
            }

            // Optional set of requested packages passed as arguments after outputDir
            Set<String> filterPackages = null;
            if (args.length > 1) {
                filterPackages = new HashSet<String>();
                for (int i = 1; i < args.length; i++) {
                    filterPackages.add(args[i].trim());
                }
            }

            Intent mainIntent = new Intent(Intent.ACTION_MAIN, null);
            mainIntent.addCategory(Intent.CATEGORY_LAUNCHER);
            List<ResolveInfo> pkgAppsList = pm.queryIntentActivities(mainIntent, 0);

            int exportedCount = 0;
            Set<String> processedPackages = new HashSet<String>();

            for (ResolveInfo info : pkgAppsList) {
                if (info == null || info.activityInfo == null) continue;
                String pkg = info.activityInfo.packageName;
                if (pkg == null || processedPackages.contains(pkg)) continue;

                if (filterPackages != null && !filterPackages.contains(pkg)) {
                    continue;
                }

                processedPackages.add(pkg);

                try {
                    Drawable icon = info.loadIcon(pm);
                    if (icon == null) {
                        icon = info.activityInfo.loadIcon(pm);
                    }
                    if (icon == null) continue;

                    int size = 128;
                    Bitmap bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
                    Canvas canvas = new Canvas(bitmap);
                    icon.setBounds(0, 0, size, size);
                    icon.draw(canvas);

                    File iconFile = new File(outDir, pkg + ".png");
                    FileOutputStream fos = new FileOutputStream(iconFile);
                    bitmap.compress(Bitmap.CompressFormat.PNG, 95, fos);
                    fos.flush();
                    fos.close();

                    System.out.println("ICON:" + pkg + ":" + iconFile.getAbsolutePath());
                    exportedCount++;
                } catch (Throwable t) {
                    // Skip failed icon
                }
            }

            System.out.println("DONE:" + exportedCount);
        } catch (Throwable e) {
            e.printStackTrace();
            System.err.println("FATAL_ERROR:" + e.getMessage());
        }
    }
}
