package io.github.yilink1.hypertraffic;

import io.github.libxposed.api.XposedInterface;
import io.github.libxposed.api.XposedModule;
import io.github.libxposed.api.XposedModuleInterface.PackageLoadedParam;
import java.lang.reflect.Method;

/**
 * HyperOS 网络助手运营商离线解锁模块 (LibXposed API 102).
 *
 * 核心逻辑：
 * 拦截小米安全中心云端下发的 is_offline 开关，强制返回 false，
 * 恢复系统原生的套餐计算链路（套餐总量 - 已用 = 剩余流量）及 ContentProvider 供给。
 */
public class TrafficHookModule extends XposedModule {

    private static final String TARGET_PKG = "com.miui.securitycenter";

    private static final String[] OFFLINE_CLASSES = {
            "com.miui.networkassistant.ui.bean.OffLineData$BaseData",
            "com.miui.networkassistant.config.SimUserInfo"
    };

    @Override
    public void onPackageLoaded(PackageLoadedParam param) {
        super.onPackageLoaded(param);

        if (!TARGET_PKG.equals(param.getPackageName())) {
            return;
        }

        ClassLoader cl = param.getDefaultClassLoader();
        if (cl == null) {
            return;
        }

        for (String className : OFFLINE_CLASSES) {
            hookIsOffline(cl, className);
        }
    }

    private void hookIsOffline(ClassLoader cl, String className) {
        try {
            Class<?> clazz = cl.loadClass(className);
            Method method = clazz.getDeclaredMethod("isOffline");

            hook(method)
                    .setExceptionMode(XposedInterface.ExceptionMode.PROTECTIVE)
                    .intercept(chain -> Boolean.FALSE);
        } catch (Throwable ignored) {
            // 安全中心非目标子进程若无此类，静默跳过
        }
    }
}
