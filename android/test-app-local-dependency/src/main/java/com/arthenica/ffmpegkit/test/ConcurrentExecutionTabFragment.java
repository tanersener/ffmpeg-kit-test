/*
 * Copyright (c) 2020-2021 Taner Sener
 *
 * This file is part of FFmpegKitTest.
 *
 * FFmpegKitTest is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FFmpegKitTest is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with FFmpegKitTest.  If not, see <http://www.gnu.org/licenses/>.
 */

package com.arthenica.ffmpegkit.test;

import android.os.Bundle;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.View;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.arthenica.ffmpegkit.ExecuteCallback;
import com.arthenica.ffmpegkit.FFmpegKit;
import com.arthenica.ffmpegkit.FFmpegKitConfig;
import com.arthenica.ffmpegkit.FFmpegSession;
import com.arthenica.ffmpegkit.LogCallback;
import com.arthenica.ffmpegkit.ReturnCode;
import com.arthenica.ffmpegkit.Session;
import com.arthenica.ffmpegkit.SessionState;
import com.arthenica.ffmpegkit.util.ResourcesUtil;
import com.arthenica.smartexception.java.Exceptions;

import java.io.File;
import java.io.IOException;
import java.util.Locale;
import java.util.concurrent.Callable;

import static com.arthenica.ffmpegkit.test.MainActivity.TAG;
import static com.arthenica.ffmpegkit.test.MainActivity.notNull;

public class ConcurrentExecutionTabFragment extends Fragment {
    private TextView outputText;
    private long sessionId1;
    private long sessionId2;
    private long sessionId3;

    public ConcurrentExecutionTabFragment() {
        super(R.layout.fragment_concurrent_tab);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        View encodeButton1 = view.findViewById(R.id.encodeButton1);
        if (encodeButton1 != null) {
            encodeButton1.setOnClickListener(new View.OnClickListener() {

                @Override
                public void onClick(View v) {
                    encodeVideo(1);
                }
            });
        }

        View encodeButton2 = view.findViewById(R.id.encodeButton2);
        if (encodeButton2 != null) {
            encodeButton2.setOnClickListener(new View.OnClickListener() {

                @Override
                public void onClick(View v) {
                    encodeVideo(2);
                }
            });
        }

        View encodeButton3 = view.findViewById(R.id.encodeButton3);
        if (encodeButton3 != null) {
            encodeButton3.setOnClickListener(new View.OnClickListener() {

                @Override
                public void onClick(View v) {
                    encodeVideo(3);
                }
            });
        }

        View cancelButton1 = view.findViewById(R.id.cancelButton1);
        if (cancelButton1 != null) {
            cancelButton1.setOnClickListener(new View.OnClickListener() {

                @Override
                public void onClick(View v) {
                    cancel(1);
                }
            });
        }

        View cancelButton2 = view.findViewById(R.id.cancelButton2);
        if (cancelButton2 != null) {
            cancelButton2.setOnClickListener(new View.OnClickListener() {

                @Override
                public void onClick(View v) {
                    cancel(2);
                }
            });
        }

        View cancelButton3 = view.findViewById(R.id.cancelButton3);
        if (cancelButton3 != null) {
            cancelButton3.setOnClickListener(new View.OnClickListener() {

                @Override
                public void onClick(View v) {
                    cancel(3);
                }
            });
        }

        View cancelButtonAll = view.findViewById(R.id.cancelButtonAll);
        if (cancelButtonAll != null) {
            cancelButtonAll.setOnClickListener(new View.OnClickListener() {

                @Override
                public void onClick(View v) {
                    cancel(0);
                }
            });
        }

        outputText = view.findViewById(R.id.outputText);
        outputText.setMovementMethod(new ScrollingMovementMethod());
    }

    @Override
    public void onResume() {
        super.onResume();
        setActive();
    }

    public static ConcurrentExecutionTabFragment newInstance() {
        return new ConcurrentExecutionTabFragment();
    }

    public void enableLogCallback() {
        FFmpegKitConfig.enableLogCallback(new LogCallback() {

            @Override
            public void apply(final com.arthenica.ffmpegkit.Log log) {
                MainActivity.addUIAction(new Callable<Object>() {

                    @Override
                    public Object call() {
                        appendOutput(String.format(Locale.getDefault(), "%d -> %s", log.getSessionId(), log.getMessage()));
                        return null;
                    }
                });
            }
        });
    }

    public void encodeVideo(final int buttonNumber) {
        final File image1File = new File(requireContext().getCacheDir(), "machupicchu.jpg");
        final File image2File = new File(requireContext().getCacheDir(), "pyramid.jpg");
        final File image3File = new File(requireContext().getCacheDir(), "stonehenge.jpg");
        final File videoFile = new File(requireContext().getFilesDir(), String.format(Locale.getDefault(), "video%d.mp4", buttonNumber));

        try {

            Log.d(TAG, String.format("Testing CONCURRENT EXECUTION for button %d.", buttonNumber));

            ResourcesUtil.resourceToFile(getResources(), R.drawable.machupicchu, image1File);
            ResourcesUtil.resourceToFile(getResources(), R.drawable.pyramid, image2File);
            ResourcesUtil.resourceToFile(getResources(), R.drawable.stonehenge, image3File);

            final String ffmpegCommand = Video.generateEncodeVideoScript(image1File.getAbsolutePath(), image2File.getAbsolutePath(), image3File.getAbsolutePath(), videoFile.getAbsolutePath(), "mpeg4", "");

            Log.d(TAG, String.format("FFmpeg process starting for button %d with arguments\n'%s'.", buttonNumber, ffmpegCommand));

            final FFmpegSession session = FFmpegKit.executeAsync(ffmpegCommand, new ExecuteCallback() {

                @Override
                public void apply(final Session session) {
                    final SessionState state = session.getState();
                    final ReturnCode returnCode = session.getReturnCode();

                    if (ReturnCode.isCancel(returnCode)) {
                        Log.d(TAG, String.format("FFmpeg process ended with cancel for button %d with sessionId %d.", buttonNumber, session.getSessionId()));
                    } else {
                        Log.d(TAG, String.format("FFmpeg process ended with state %s and rc %s for button %d with sessionId %d.%s", state, returnCode, buttonNumber, session.getSessionId(), notNull(session.getFailStackTrace(), "\n")));
                    }
                }
            });

            final long sessionId = session.getSessionId();

            Log.d(TAG, String.format("Async FFmpeg process started for button %d with sessionId %d.", buttonNumber, sessionId));

            switch (buttonNumber) {
                case 1: {
                    sessionId1 = sessionId;
                }
                break;
                case 2: {
                    sessionId2 = sessionId;
                }
                break;
                default: {
                    sessionId3 = sessionId;
                }
            }

        } catch (IOException e) {
            Log.e(TAG, String.format("Encode video failed %s.", Exceptions.getStackTraceString(e)));
            Popup.show(requireContext(), "Encode video failed");
        }

        MainActivity.listFFmpegSessions();
    }

    public void cancel(final int buttonNumber) {
        long sessionId = 0;

        switch (buttonNumber) {
            case 1: {
                sessionId = sessionId1;
            }
            break;
            case 2: {
                sessionId = sessionId2;
            }
            break;
            case 3: {
                sessionId = sessionId3;
            }
        }

        Log.d(TAG, String.format("Cancelling FFmpeg process for button %d with sessionId %d.", buttonNumber, sessionId));

        if (sessionId == 0) {
            FFmpegKit.cancel();
        } else {
            FFmpegKit.cancel(sessionId);
        }
    }

    public void setActive() {
        Log.i(MainActivity.TAG, "Concurrent Execution Tab Activated");
        enableLogCallback();
        Popup.show(requireContext(), getString(R.string.concurrent_execution_test_tooltip_text));
    }

    public void appendOutput(final String logMessage) {
        outputText.append(logMessage);
    }

}
