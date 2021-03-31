package com.example.testplugin.matrix;

import android.app.Application;

import com.example.testplugin.matrix.config.DynamicConfigImplDemo;
import com.example.testplugin.matrix.listener.TestPluginListener;
import com.tencent.matrix.Matrix;
import com.tencent.matrix.iocanary.IOCanaryPlugin;
import com.tencent.matrix.iocanary.config.IOConfig;
import com.tencent.matrix.trace.TracePlugin;
import com.tencent.matrix.trace.config.TraceConfig;
import com.tencent.matrix.util.MatrixLog;
import com.tencent.sqlitelint.SQLiteLint;
import com.tencent.sqlitelint.SQLiteLintPlugin;
import com.tencent.sqlitelint.config.SQLiteLintConfig;

public class MatrixUtil {

    private static String TAG = "MatrixUtil";

    public static void init(Application application) {
        DynamicConfigImplDemo dynamicConfig = new DynamicConfigImplDemo();
        boolean matrixEnable = dynamicConfig.isMatrixEnable();
        boolean fpsEnable = dynamicConfig.isFPSEnable();
        boolean traceEnable = dynamicConfig.isTraceEnable();

        Matrix.Builder builder = new Matrix.Builder(application);
        builder.patchListener(new TestPluginListener(application.getApplicationContext()));

        //trace
        TraceConfig traceConfig = new TraceConfig.Builder()
                .dynamicConfig(dynamicConfig)
                .enableFPS(fpsEnable)
                .enableEvilMethodTrace(traceEnable)
                .enableAnrTrace(traceEnable)
                .enableStartup(traceEnable)
//                .splashActivities("sample.tencent.matrix.SplashActivity;")
                .isDebug(true)
                .isDevEnv(false)
                .build();

        TracePlugin tracePlugin = (new TracePlugin(traceConfig));
        builder.plugin(tracePlugin);

        if (matrixEnable) {

            //resource
//            Intent intent = new Intent();
//            ResourceConfig.DumpMode mode = ResourceConfig.DumpMode.AUTO_DUMP;
//            MatrixLog.i(TAG, "Dump Activity Leak Mode=%s", mode);
//            intent.setClassName(this.getPackageName(), "com.tencent.mm.ui.matrix.ManualDumpActivity");
//            ResourceConfig resourceConfig = new ResourceConfig.Builder()
//                    .dynamicConfig(dynamicConfig)
//                    .setAutoDumpHprofMode(mode)
////                .setDetectDebuger(true) //matrix test code
//                    .setNotificationContentIntent(intent)
//                    .build();
//            builder.plugin(new ResourcePlugin(resourceConfig));
//            ResourcePlugin.activityLeakFixer(application);

            //io
            IOCanaryPlugin ioCanaryPlugin = new IOCanaryPlugin(new IOConfig.Builder()
                    .dynamicConfig(dynamicConfig)
                    .build());
            builder.plugin(ioCanaryPlugin);


            // prevent api 19 UnsatisfiedLinkError
            //sqlite
            SQLiteLintConfig sqlLiteConfig;
            try {
                sqlLiteConfig = new SQLiteLintConfig(SQLiteLint.SqlExecutionCallbackMode.CUSTOM_NOTIFY);
            } catch (Throwable t) {
                sqlLiteConfig = new SQLiteLintConfig(SQLiteLint.SqlExecutionCallbackMode.CUSTOM_NOTIFY);
            }
            builder.plugin(new SQLiteLintPlugin(sqlLiteConfig));


//            ThreadMonitor threadMonitor = new ThreadMonitor(new ThreadMonitorConfig.Builder().build());
//            builder.plugin(threadMonitor);

//            BatteryMonitor batteryMonitor = new BatteryMonitor(new BatteryMonitor.Builder()
//                    .installPlugin(LooperTaskMonitorPlugin.class)
//                    .installPlugin(JiffiesMonitorPlugin.class)
//                    .installPlugin(WakeLockMonitorPlugin.class)
//                    .disableAppForegroundNotifyByMatrix(false)
//                    .wakelockTimeout(2 * 60 * 1000)
//                    .greyJiffiesTime(2 * 1000)
//                    .build()
//            );
//            builder.plugin(batteryMonitor);
        }

        Matrix.init(builder.build());

        //start only startup tracer, close other tracer.
        tracePlugin.start();
//        Matrix.with().getPluginByClass(ThreadMonitor.class).start();
//        Matrix.with().getPluginByClass(BatteryMonitor.class).start();
        MatrixLog.i("Matrix.HackCallback", "end:%s", System.currentTimeMillis());

    }
}
