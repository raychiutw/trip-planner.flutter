package com.raychiu.tripline;

import android.graphics.Point;
import android.graphics.Rect;
import android.os.SystemClock;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.UiDevice;
import androidx.test.uiautomator.UiObject;
import androidx.test.uiautomator.UiObjectNotFoundException;
import androidx.test.uiautomator.UiSelector;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

import static org.junit.Assert.assertFalse;

@RunWith(Parameterized.class)
public class MainActivityTest {
    private static final String MAP_LABEL = "Tripline native map evidence canvas";
    private static final String PINCH_REQUEST_LABEL = "Tripline native map pinch request";
    private static final String ROTATE_REQUEST_LABEL = "Tripline native map rotate request";
    private static final String DOUBLE_TAP_REQUEST_LABEL = "Tripline native map double tap request";
    private static final String NATIVE_MAP_TEST_NAME = "native Google Map renders";
    private static final long DOUBLE_TAP_INTERVAL_MS = 100;

    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        Thread gestureBridge = dartTestName.contains(NATIVE_MAP_TEST_NAME)
                ? startNativeMapGestureBridge(instrumentation)
                : null;
        try {
            instrumentation.runDartTest(dartTestName);
        } finally {
            if (gestureBridge != null) {
                gestureBridge.interrupt();
                try {
                    gestureBridge.join(5000);
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                }
                assertFalse("Native map gesture bridge did not stop", gestureBridge.isAlive());
            }
        }
    }

    private static Thread startNativeMapGestureBridge(PatrolJUnitRunner instrumentation) {
        Thread bridge = new Thread(() -> {
            UiDevice device = UiDevice.getInstance(instrumentation);
            UiObject map = device.findObject(new UiSelector().description(MAP_LABEL));
            String activeRequest = null;

            while (!Thread.currentThread().isInterrupted()) {
                String request = device.findObject(new UiSelector().description(PINCH_REQUEST_LABEL)).exists()
                        ? PINCH_REQUEST_LABEL
                        : (device.findObject(new UiSelector().description(ROTATE_REQUEST_LABEL)).exists()
                                ? ROTATE_REQUEST_LABEL
                                : (device.findObject(new UiSelector().description(DOUBLE_TAP_REQUEST_LABEL)).exists()
                                        ? DOUBLE_TAP_REQUEST_LABEL
                                        : null));
                if (request == null) {
                    activeRequest = null;
                } else if (!request.equals(activeRequest) && injectGesture(device, map, request)) {
                    activeRequest = request;
                }
                SystemClock.sleep(250);
            }
        }, "tripline-native-map-gestures");
        bridge.start();
        return bridge;
    }

    private static boolean injectGesture(UiDevice device, UiObject map, String request) {
        try {
            if (PINCH_REQUEST_LABEL.equals(request)) {
                return map.pinchOut(60, 30);
            }

            Rect bounds = map.getBounds();
            int centerX = bounds.centerX();
            int centerY = bounds.centerY();
            if (DOUBLE_TAP_REQUEST_LABEL.equals(request)) {
                if (!device.click(centerX, centerY)) {
                    return false;
                }
                SystemClock.sleep(DOUBLE_TAP_INTERVAL_MS);
                return device.click(centerX, centerY);
            }

            int radius = Math.min(bounds.width(), bounds.height()) / 5;
            return map.performTwoPointerGesture(
                    new Point(centerX - radius, centerY),
                    new Point(centerX + radius, centerY),
                    new Point(centerX, centerY - radius),
                    new Point(centerX, centerY + radius),
                    40);
        } catch (UiObjectNotFoundException ignored) {
            return false;
        }
    }
}
