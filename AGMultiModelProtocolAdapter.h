// ==============================================================================
// File: AGMultiModelProtocolAdapter.h
// Description: 国内外全厂商 AI 模型协议独立适配器 (WebSocket Realtime & HTTP SSE)
// 原则：完全独立封装，零侵入现有 Gemini、摄像头状态机与音频硬件采集/播放引擎
// ==============================================================================

#ifndef AGMultiModelProtocolAdapter_h
#define AGMultiModelProtocolAdapter_h

#import <Foundation/Foundation.h>

// WebSocket 实时全双工语音/视频协议家族
typedef NS_ENUM(NSInteger, AGWSProtocolFamily) {
    AGWSProtocolFamilyGoogleBidi        = 0, // Google Gemini Live BidiGenerateContent
    AGWSProtocolFamilyDashScopeRealtime = 1, // 阿里云百炼 Qwen-Omni-Realtime / Qwen-Audio-Realtime
    AGWSProtocolFamilyZhipuGLMRealtime  = 2, // 智谱清言 GLM-Realtime / GLM-4-Voice-Realtime
    AGWSProtocolFamilyStepFunRealtime   = 3, // 阶跃星辰 StepAudio-2 / StepAudio-2.5 Realtime
    AGWSProtocolFamilyVolcDoubaoRealtime= 4, // 字节火山引擎 Doubao Realtime (OpenAI Realtime 兼容网关)
    AGWSProtocolFamilyOpenAIRealtime    = 5  // OpenAI GPT-Realtime / GPT-4o-Realtime 及通用兼容网关
};

// HTTP 流式对话协议家族
typedef NS_ENUM(NSInteger, AGHTTPProtocolFamily) {
    AGHTTPProtocolFamilyGoogleNative  = 0, // Google Gemini streamGenerateContent
    AGHTTPProtocolFamilyAnthropic     = 1, // Anthropic Claude Native (/v1/messages)
    AGHTTPProtocolFamilyOpenAICompat  = 2  // OpenAI / DeepSeek / Qwen / GLM / Doubao / Kimi / StepFun / MiniMax / Grok
};

static inline NSString *agGenerateRealtimeEventID(void) {
    return [NSString stringWithFormat:@"evt_%ld_%04u", (long)[[NSDate date] timeIntervalSince1970], arc4random_uniform(10000)];
}

// 1. 识别 WebSocket 协议家族
static inline AGWSProtocolFamily agDetectWSProtocolFamily(NSString *endpoint, NSString *modelID) {
    NSString *ep = [endpoint lowercaseString] ?: @"";
    NSString *m  = [modelID lowercaseString] ?: @"";

    if ([ep containsString:@"googleapis.com"] || [ep containsString:@"v1beta"] || [ep containsString:@"v1alpha"]) {
        if (![ep containsString:@"/v1/chat/completions"] && ![ep containsString:@"openai"]) {
            return AGWSProtocolFamilyGoogleBidi;
        }
    }
    if ([ep containsString:@"dashscope"] || [ep containsString:@"aliyuncs.com"] || [m containsString:@"qwen"]) {
        return AGWSProtocolFamilyDashScopeRealtime;
    }
    if ([ep containsString:@"bigmodel.cn"] || [ep containsString:@"z.ai"] || [m hasPrefix:@"glm-"]) {
        return AGWSProtocolFamilyZhipuGLMRealtime;
    }
    if ([ep containsString:@"stepfun"] || [m hasPrefix:@"step-"] || [m hasPrefix:@"stepaudio"]) {
        return AGWSProtocolFamilyStepFunRealtime;
    }
    if ([ep containsString:@"volces.com"] || [ep containsString:@"bytedance"] || [m containsString:@"doubao"]) {
        return AGWSProtocolFamilyVolcDoubaoRealtime;
    }
    return AGWSProtocolFamilyOpenAIRealtime;
}

// 2. 识别 HTTP 协议家族
static inline AGHTTPProtocolFamily agDetectHTTPProtocolFamily(NSString *endpoint, NSString *modelID) {
    NSString *ep = [endpoint lowercaseString] ?: @"";
    NSString *m  = [modelID lowercaseString] ?: @"";

    if ([ep containsString:@"googleapis.com"] || [ep containsString:@"v1beta"] || [ep containsString:@"v1alpha"]) {
        if (![ep containsString:@"/v1/chat/completions"] && ![ep containsString:@"openai"]) {
            return AGHTTPProtocolFamilyGoogleNative;
        }
    }
    // 仅当直连 Anthropic 官方端点且路径未指定 /chat/completions 时启用原生 /v1/messages 协议
    if (([ep containsString:@"api.anthropic.com"] || ([m hasPrefix:@"claude-"] && [ep containsString:@"anthropic"])) &&
        ![ep containsString:@"/chat/completions"]) {
        return AGHTTPProtocolFamilyAnthropic;
    }
    return AGHTTPProtocolFamilyOpenAICompat;
}

// 3. 过滤不可用于双向对话的单向 ASR / TTS / 纯同传模型
static inline BOOL agIsUnidirectionalAudioModel(NSString *lowerModelID) {
    if (!lowerModelID || lowerModelID.length == 0) return NO;
    if ([lowerModelID containsString:@"-asr"] || [lowerModelID hasPrefix:@"asr-"] ||
        [lowerModelID containsString:@"paraformer"] || [lowerModelID containsString:@"sensevoice"] ||
        [lowerModelID containsString:@"cosyvoice"] || [lowerModelID containsString:@"sambert"] ||
        [lowerModelID containsString:@"livetranslate"] || [lowerModelID containsString:@"live-translate"] ||
        [lowerModelID containsString:@"gummy-"] || [lowerModelID containsString:@"whisper"] ||
        [lowerModelID containsString:@"transcribe"] || [lowerModelID containsString:@"-tts"]) {
        return YES;
    }
    return NO;
}

// 4. 判断是否为支持双向语音的 WebSocket Realtime 模型
static inline BOOL agIsBidirectionalRealtimeModelID(NSString *modelID, NSDictionary *mDict) {
    if (!modelID || modelID.length == 0) return NO;
    NSString *lower = [modelID lowercaseString];
    if (agIsUnidirectionalAudioModel(lower)) return NO;

    NSArray *methods = mDict[@"supportedGenerationMethods"];
    if ([methods isKindOfClass:[NSArray class]] && [methods containsObject:@"bidiGenerateContent"]) {
        return YES;
    }
    if ([lower containsString:@"native-audio"] ||
        [lower containsString:@"-live"] ||
        [lower containsString:@"realtime"] ||
        [lower containsString:@"2.0-flash-exp"] ||
        [lower isEqualToString:@"step-audio-2"] ||
        [lower isEqualToString:@"step-audio-2-mini"] ||
        [lower isEqualToString:@"step-audio-2-think"] ||
        [lower isEqualToString:@"step-audio-2-mini-think"] ||
        [lower isEqualToString:@"step-1o-audio"]) {
        return YES;
    }
    return NO;
}

// 5. 构建各厂商官方 WebSocket 握手请求 (URL + 鉴权 Header)
static inline NSMutableURLRequest *agBuildVendorWebSocketRequest(NSString *endpoint, NSString *exactModelID, NSString *apiKey) {
    AGWSProtocolFamily family = agDetectWSProtocolFamily(endpoint, exactModelID);
    NSString *cleanEP = [endpoint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([cleanEP hasSuffix:@"/"]) cleanEP = [cleanEP substringToIndex:cleanEP.length - 1];

    NSString *hostBase = [[cleanEP stringByReplacingOccurrencesOfString:@"https://" withString:@"wss://"]
                          stringByReplacingOccurrencesOfString:@"http://" withString:@"ws://"];
    if (![hostBase hasPrefix:@"wss://"] && ![hostBase hasPrefix:@"ws://"]) {
        hostBase = [@"wss://" stringByAppendingString:hostBase];
    }

    // 剥离用户在设置中可能粘贴的 HTTP 路径后缀（如 /compatible-mode/v1 或 /v1/chat/completions）
    NSArray *stripSuffixes = @[
        @"/compatible-mode/v1/chat/completions",
        @"/compatible-mode/v1",
        @"/api/paas/v4/chat/completions",
        @"/api/paas/v4",
        @"/api/v3/chat/completions",
        @"/api/v3",
        @"/v1/chat/completions",
        @"/chat/completions"
    ];
    for (NSString *suf in stripSuffixes) {
        if ([hostBase hasSuffix:suf]) {
            hostBase = [hostBase substringToIndex:hostBase.length - suf.length];
            break;
        }
    }

    NSString *encodedModel = [exactModelID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: exactModelID;
    NSString *wsURLStr = nil;

    switch (family) {
        case AGWSProtocolFamilyDashScopeRealtime: {
            // 阿里云百炼官方 WebSocket 端点: wss://dashscope.aliyuncs.com/api-ws/v1/realtime?model=xxx
            if ([hostBase containsString:@"/api-ws/v1/realtime"]) {
                wsURLStr = [NSString stringWithFormat:@"%@?model=%@", hostBase, encodedModel];
            } else if ([hostBase hasSuffix:@"/api-ws/v1"]) {
                wsURLStr = [NSString stringWithFormat:@"%@/realtime?model=%@", hostBase, encodedModel];
            } else {
                wsURLStr = [NSString stringWithFormat:@"%@/api-ws/v1/realtime?model=%@", hostBase, encodedModel];
            }
            break;
        }
        case AGWSProtocolFamilyZhipuGLMRealtime: {
            // 智谱官方 WebSocket 端点: wss://open.bigmodel.cn/api/paas/v4/realtime?model=glm-realtime
            if ([hostBase containsString:@"/api/paas/v4/realtime"]) {
                wsURLStr = [NSString stringWithFormat:@"%@?model=%@", hostBase, encodedModel];
            } else {
                wsURLStr = [NSString stringWithFormat:@"%@/api/paas/v4/realtime?model=%@", hostBase, encodedModel];
            }
            break;
        }
        case AGWSProtocolFamilyStepFunRealtime:
        case AGWSProtocolFamilyVolcDoubaoRealtime:
        case AGWSProtocolFamilyOpenAIRealtime:
        default: {
            if ([hostBase hasSuffix:@"/v1/realtime"]) {
                wsURLStr = [NSString stringWithFormat:@"%@?model=%@", hostBase, encodedModel];
            } else if ([hostBase hasSuffix:@"/v1"]) {
                wsURLStr = [NSString stringWithFormat:@"%@/realtime?model=%@", hostBase, encodedModel];
            } else {
                wsURLStr = [NSString stringWithFormat:@"%@/v1/realtime?model=%@", hostBase, encodedModel];
            }
            break;
        }
    }

    NSURL *wsURL = [NSURL URLWithString:wsURLStr];
    if (!wsURL) return nil;

    NSMutableURLRequest *wsReq = [NSMutableURLRequest requestWithURL:wsURL];
    [wsReq setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
    if (family == AGWSProtocolFamilyOpenAIRealtime || family == AGWSProtocolFamilyDashScopeRealtime) {
        [wsReq setValue:@"realtime=v1" forHTTPHeaderField:@"OpenAI-Beta"];
    }
    return wsReq;
}

// 6. 构建手机自动化 Function Calling 工具声明 (适用于 OpenAI / DashScope / GLM / StepFun Realtime)
static inline NSArray<NSDictionary *> *agRealtimeAutomationToolsSchema(void) {
    return @[
        @{
            @"type": @"function",
            @"name": @"execute_device_action",
            @"description": @"控制用户的 iPhone 手机执行系统级自动化操作，如打开应用、发微信、查未读微信、开关手电筒、调节音量/亮度、截屏、定闹钟/倒计时、地图导航、平台搜索、屏幕点击/滑动手势等。",
            @"parameters": @{
                @"type": @"object",
                @"properties": @{
                    @"type": @{
                        @"type": @"string",
                        @"description": @"操作类型枚举：open_app, wechat_message, wechat_read_unread, wechat_open_chat, wechat_shortcut, alipay_shortcut, volume_control, media_control, brightness_control, toggle_flashlight, take_screenshot, alarm_control, timer_control, reminder_add, ui_tap_text, ui_gesture, kill_background_apps, appearance_mode, wifi_toggle, bluetooth_toggle, airplane_mode, low_power_mode, clipboard_auto_type, device_status, navigation, search, make_call, send_sms, system_control"
                    },
                    @"app": @{ @"type": @"string", @"description": @"应用名称或导航偏好 (如 微信, 抖音, amap, baidu)" },
                    @"target": @{ @"type": @"string", @"description": @"微信/电话/短信的目标联系人姓名" },
                    @"content": @{ @"type": @"string", @"description": @"发送的微信/短信内容" },
                    @"action": @{ @"type": @"string", @"description": @"子动作 (如 up, down, mute, set, play, pause, next, prev, home, lock, respring)" },
                    @"level": @{ @"type": @"number", @"description": @"音量或亮度数值 (0.0 到 1.0)" },
                    @"on": @{ @"type": @"boolean", @"description": @"开关状态 (true 或 false)" },
                    @"feature": @{ @"type": @"string", @"description": @"快捷功能 (scan, pay, receipt, moments, bus)" },
                    @"keyword": @{ @"type": @"string", @"description": @"搜索关键词" },
                    @"platform": @{ @"type": @"string", @"description": @"搜索平台 (taobao, jd, douyin, bilibili, xhs, meituan, baidu)" },
                    @"destination": @{ @"type": @"string", @"description": @"导航目的地" },
                    @"text": @{ @"type": @"string", @"description": @"屏幕上要点击的文字或要复制打字的文本" },
                    @"gesture": @{ @"type": @"string", @"description": @"手势类型 (swipe_up, swipe_down, double_tap, back)" },
                    @"hour": @{ @"type": @"integer", @"description": @"闹钟小时 (0-23)" },
                    @"minute": @{ @"type": @"integer", @"description": @"闹钟分钟 (0-59)" },
                    @"seconds": @{ @"type": @"integer", @"description": @"倒计时秒数" }
                },
                @"required": @[@"type"]
            }
        }
    ];
}

// 7. 构建各厂商官方规范的 session.update 握手配置包
static inline NSDictionary *agBuildVendorSessionUpdatePayload(NSString *endpoint, NSString *rawModel, NSString *sysInstruction, BOOL isVideoActive, BOOL minimalFallback) {
    AGWSProtocolFamily family = agDetectWSProtocolFamily(endpoint, rawModel);
    NSString *eventID = agGenerateRealtimeEventID();

    switch (family) {
        case AGWSProtocolFamilyDashScopeRealtime: {
            // 阿里云百炼 Qwen-Omni-Realtime / Qwen-Audio-Realtime 官方规范：
            // 音色必须为 Chelsie / Cherry / Serena / Ethan，上行 16kHz PCM16，下行 24kHz PCM16
            // 注意：Qwen-Omni-Realtime 官方文档明确规定不支持 tool_choice 与 parallel_tool_calls 字段
            NSMutableDictionary *sessionDict = [@{
                @"modalities": @[@"text", @"audio"],
                @"instructions": sysInstruction,
                @"voice": @"Chelsie",
                @"input_audio_format": @"pcm16",
                @"output_audio_format": @"pcm16",
                @"turn_detection": @{
                    @"type": @"server_vad",
                    @"threshold": @(0.5),
                    @"prefix_padding_ms": @(300),
                    @"silence_duration_ms": @(600)
                }
            } mutableCopy];
            if (!minimalFallback) {
                sessionDict[@"input_audio_transcription"] = @{ @"model": @"gummy-realtime-v1" };
                sessionDict[@"tools"] = agRealtimeAutomationToolsSchema();
            }
            return @{
                @"event_id": eventID,
                @"type": @"session.update",
                @"session": sessionDict
            };
        }
        case AGWSProtocolFamilyZhipuGLMRealtime: {
            // 智谱清言 GLM-Realtime 官方规范：input_audio_format: "pcm", beta_fields 必填
            NSMutableDictionary *sessionDict = [@{
                @"modalities": @[@"text", @"audio"],
                @"instructions": sysInstruction,
                @"input_audio_format": @"pcm",
                @"output_audio_format": @"pcm",
                @"turn_detection": @{ @"type": @"server_vad" },
                @"beta_fields": @{
                    @"chat_mode": isVideoActive ? @"video" : @"audio",
                    @"tts_source": @"e2e",
                    @"auto_search": @YES
                }
            } mutableCopy];
            if (!minimalFallback) {
                sessionDict[@"tools"] = agRealtimeAutomationToolsSchema();
            }
            return @{
                @"event_id": eventID,
                @"type": @"session.update",
                @"session": sessionDict
            };
        }
        case AGWSProtocolFamilyStepFunRealtime: {
            // 阶跃星辰 StepAudio-2 / 2.5 官方规范：voice 必填且需为官方音色名 (如 qingchunshaonv)
            NSMutableDictionary *sessionDict = [@{
                @"modalities": @[@"text", @"audio"],
                @"instructions": sysInstruction,
                @"voice": @"qingchunshaonv",
                @"input_audio_format": @"pcm16",
                @"output_audio_format": @"pcm16",
                @"turn_detection": @{ @"type": @"server_vad" }
            } mutableCopy];
            if (!minimalFallback) {
                sessionDict[@"tools"] = agRealtimeAutomationToolsSchema();
            }
            return @{
                @"event_id": eventID,
                @"type": @"session.update",
                @"session": sessionDict
            };
        }
        case AGWSProtocolFamilyVolcDoubaoRealtime:
        case AGWSProtocolFamilyOpenAIRealtime:
        default: {
            NSMutableDictionary *sessionDict = [@{
                @"modalities": @[@"text", @"audio"],
                @"instructions": sysInstruction,
                @"voice": @"alloy",
                @"input_audio_format": @"pcm16",
                @"output_audio_format": @"pcm16",
                @"turn_detection": @{
                    @"type": @"server_vad",
                    @"threshold": @(0.5),
                    @"prefix_padding_ms": @(300),
                    @"silence_duration_ms": @(500),
                    @"create_response": @YES
                }
            } mutableCopy];
            if (!minimalFallback) {
                sessionDict[@"input_audio_transcription"] = @{ @"model": @"whisper-1" };
                sessionDict[@"tools"] = agRealtimeAutomationToolsSchema();
            }
            return @{
                @"event_id": eventID,
                @"type": @"session.update",
                @"session": sessionDict
            };
        }
    }
}

// 8. 获取各厂商 WebSocket 协议要求的上行麦克风采样率
static inline double agVendorTargetInputSampleRate(NSString *endpoint, NSString *modelID) {
    AGWSProtocolFamily family = agDetectWSProtocolFamily(endpoint, modelID);
    switch (family) {
        case AGWSProtocolFamilyGoogleBidi:
        case AGWSProtocolFamilyDashScopeRealtime:
        case AGWSProtocolFamilyZhipuGLMRealtime:
            return 16000.0; // Google Bidi、阿里 Qwen-Omni-Realtime、智谱 GLM-Realtime 官方要求上行 16kHz PCM
        case AGWSProtocolFamilyStepFunRealtime:
        case AGWSProtocolFamilyVolcDoubaoRealtime:
        case AGWSProtocolFamilyOpenAIRealtime:
        default:
            return 24000.0; // OpenAI / StepFun 标准为 24kHz PCM
    }
}

// 9. 构建上行实时音频流 JSON 报文
static inline NSDictionary *agBuildVendorAudioAppendPacket(NSString *base64PCM) {
    return @{
        @"event_id": agGenerateRealtimeEventID(),
        @"type": @"input_audio_buffer.append",
        @"audio": base64PCM ?: @""
    };
}

// 10. 构建上行实时摄像头视频帧 JSON 报文（非 Google 协议）
static inline NSDictionary *agBuildVendorVideoFramePacket(NSString *endpoint, NSString *modelID, NSString *base64JPEG) {
    if (!base64JPEG || base64JPEG.length == 0) return nil;
    AGWSProtocolFamily family = agDetectWSProtocolFamily(endpoint, modelID);
    NSString *eventID = agGenerateRealtimeEventID();

    if (family == AGWSProtocolFamilyDashScopeRealtime) {
        // 阿里云百炼 Qwen-Omni-Realtime 官方视频帧事件: input_image_buffer.append
        return @{
            @"event_id": eventID,
            @"type": @"input_image_buffer.append",
            @"image": base64JPEG
        };
    } else if (family == AGWSProtocolFamilyZhipuGLMRealtime) {
        // 智谱 GLM-Realtime 官方视频帧事件: input_audio_buffer.append_video_frame
        return @{
            @"event_id": eventID,
            @"type": @"input_audio_buffer.append_video_frame",
            @"video_frame": base64JPEG
        };
    } else if (family == AGWSProtocolFamilyOpenAIRealtime) {
        // OpenAI Realtime (gpt-realtime / gpt-4o-realtime) 图像注入事件
        return @{
            @"event_id": eventID,
            @"type": @"conversation.item.create",
            @"item": @{
                @"type": @"message",
                @"role": @"user",
                @"content": @[
                    @{
                        @"type": @"input_image",
                        @"image_url": [NSString stringWithFormat:@"data:image/jpeg;base64,%@", base64JPEG]
                    }
                ]
            }
        };
    }
    return nil;
}

// 11. 规范化国内外各厂商的 HTTP Chat Completions 地址
static inline NSString *agResolveVendorHTTPChatEndpoint(NSString *rawEndpoint, NSString *modelID) {
    NSString *ep = [rawEndpoint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([ep hasSuffix:@"/"]) ep = [ep substringToIndex:ep.length - 1];

    AGHTTPProtocolFamily httpFamily = agDetectHTTPProtocolFamily(ep, modelID);
    if (httpFamily == AGHTTPProtocolFamilyAnthropic) {
        if ([ep hasSuffix:@"/v1/messages"]) return ep;
        if ([ep hasSuffix:@"/v1"]) return [ep stringByAppendingString:@"/messages"];
        return [ep stringByAppendingString:@"/v1/messages"];
    }

    if ([ep hasSuffix:@"/chat/completions"]) return ep;

    if ([ep containsString:@"dashscope.aliyuncs.com"] || [ep containsString:@"dashscope-intl.aliyuncs.com"]) {
        if (![ep containsString:@"/compatible-mode/v1"]) {
            ep = [ep stringByAppendingString:@"/compatible-mode/v1"];
        }
    } else if ([ep containsString:@"open.bigmodel.cn"] || [ep containsString:@"api.z.ai"]) {
        if (![ep containsString:@"/api/paas/v4"]) {
            ep = [ep stringByAppendingString:@"/api/paas/v4"];
        }
    } else if ([ep containsString:@"volces.com"]) {
        if (![ep containsString:@"/api/v3"]) {
            ep = [ep stringByAppendingString:@"/api/v3"];
        }
    } else if ([ep containsString:@"qianfan.baidubce.com"]) {
        if (![ep containsString:@"/v2"]) {
            ep = [ep stringByAppendingString:@"/v2"];
        }
    } else if (![ep hasSuffix:@"/v1"] && ![ep hasSuffix:@"/v2"] && ![ep hasSuffix:@"/v3"] && ![ep hasSuffix:@"/v4"]) {
        ep = [ep stringByAppendingString:@"/v1"];
    }
    return [ep stringByAppendingString:@"/chat/completions"];
}

// 12. 规范化国内外各厂商的 /models 模型列表拉取地址
static inline NSString *agResolveVendorModelsListEndpoint(NSString *rawEndpoint, NSString *apiKey) {
    NSString *cleanEP = [rawEndpoint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([cleanEP hasSuffix:@"/"]) cleanEP = [cleanEP substringToIndex:cleanEP.length - 1];

    if ([cleanEP containsString:@"googleapis.com"] || [cleanEP containsString:@"v1beta"]) {
        return [NSString stringWithFormat:@"%@/v1beta/models?pageSize=100&key=%@", cleanEP, apiKey ?: @""];
    }
    if ([cleanEP containsString:@"dashscope.aliyuncs.com"]) {
        return @"https://dashscope.aliyuncs.com/compatible-mode/v1/models";
    }
    if ([cleanEP containsString:@"dashscope-intl.aliyuncs.com"]) {
        return @"https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models";
    }
    if ([cleanEP containsString:@"open.bigmodel.cn"]) {
        return @"https://open.bigmodel.cn/api/paas/v4/models";
    }
    if ([cleanEP containsString:@"api.z.ai"]) {
        return @"https://api.z.ai/api/paas/v4/models";
    }
    if ([cleanEP containsString:@"volces.com"]) {
        return @"https://ark.cn-beijing.volces.com/api/v3/models";
    }
    if ([cleanEP hasSuffix:@"/chat/completions"]) {
        return [cleanEP stringByReplacingOccurrencesOfString:@"/chat/completions" withString:@"/models"];
    }
    if ([cleanEP hasSuffix:@"/v1"] || [cleanEP hasSuffix:@"/v2"] || [cleanEP hasSuffix:@"/v3"] || [cleanEP hasSuffix:@"/v4"]) {
        return [NSString stringWithFormat:@"%@/models", cleanEP];
    }
    return [NSString stringWithFormat:@"%@/v1/models", cleanEP];
}

// 13. 国内外主流厂商全量最新模型补充/兜底清单 (当厂商 /models 接口未返回 Realtime 模型或限制枚举时自动补充)
static inline NSArray<NSDictionary *> *agVendorSupplementalModels(NSString *endpoint, NSInteger tab) {
    NSString *ep = [endpoint lowercaseString] ?: @"";
    BOOL isVoiceOrVideoTab = (tab == 0 || tab == 1);

    if ([ep containsString:@"dashscope"] || [ep containsString:@"aliyuncs"]) {
        if (isVoiceOrVideoTab) {
            return @[
                @{@"id": @"qwen3.5-omni-flash-realtime", @"bidi": @YES, @"onlyBidi": @YES},
                @{@"id": @"qwen3.5-omni-plus-realtime",  @"bidi": @YES, @"onlyBidi": @YES},
                @{@"id": @"qwen3-omni-flash-realtime",   @"bidi": @YES, @"onlyBidi": @YES},
                @{@"id": @"qwen-omni-turbo-realtime",    @"bidi": @YES, @"onlyBidi": @YES},
                @{@"id": @"qwen3.8-omni-flash-realtime", @"bidi": @YES, @"onlyBidi": @YES}
            ];
        }
        return @[
            @{@"id": @"qwen-max",            @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"qwen-plus",           @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"qwen-turbo",          @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"qwen-vl-max",         @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"qwen-omni-turbo",     @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"qwq-32b",             @"bidi": @NO, @"onlyBidi": @NO}
        ];
    }
    if ([ep containsString:@"bigmodel.cn"] || [ep containsString:@"z.ai"]) {
        if (isVoiceOrVideoTab) {
            return @[
                @{@"id": @"glm-realtime",       @"bidi": @YES, @"onlyBidi": @YES},
                @{@"id": @"glm-4-plus",         @"bidi": @NO,  @"onlyBidi": @NO},
                @{@"id": @"glm-4-flash",        @"bidi": @NO,  @"onlyBidi": @NO},
                @{@"id": @"glm-4v-plus",        @"bidi": @NO,  @"onlyBidi": @NO}
            ];
        }
        return @[
            @{@"id": @"glm-4-plus",  @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"glm-4-flash", @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"glm-4v-plus", @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"glm-4-air",   @"bidi": @NO, @"onlyBidi": @NO}
        ];
    }
    if ([ep containsString:@"stepfun"]) {
        if (isVoiceOrVideoTab) {
            return @[
                @{@"id": @"step-audio-2",       @"bidi": @YES, @"onlyBidi": @YES},
                @{@"id": @"step-audio-2-mini",  @"bidi": @YES, @"onlyBidi": @YES},
                @{@"id": @"step-audio-2-think", @"bidi": @YES, @"onlyBidi": @YES},
                @{@"id": @"step-1o-audio",      @"bidi": @YES, @"onlyBidi": @YES}
            ];
        }
        return @[
            @{@"id": @"step-2-16k",  @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"step-1v-32k", @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"step-1-flash",@"bidi": @NO, @"onlyBidi": @NO}
        ];
    }
    if ([ep containsString:@"volces.com"] || [ep containsString:@"bytedance"]) {
        return @[
            @{@"id": @"doubao-1-5-pro-32k-250115",        @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"doubao-1-5-vision-pro-32k-250115", @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"doubao-1-5-lite-32k-250115",       @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"deepseek-v3-250324",               @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"deepseek-r1-250120",               @"bidi": @NO, @"onlyBidi": @NO}
        ];
    }
    if ([ep containsString:@"deepseek"]) {
        return @[
            @{@"id": @"deepseek-chat",     @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"deepseek-reasoner", @"bidi": @NO, @"onlyBidi": @NO}
        ];
    }
    if ([ep containsString:@"moonshot"]) {
        return @[
            @{@"id": @"kimi-latest",      @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"moonshot-v1-8k",   @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"moonshot-v1-32k",  @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"moonshot-v1-128k", @"bidi": @NO, @"onlyBidi": @NO}
        ];
    }
    if ([ep containsString:@"minimax"]) {
        return @[
            @{@"id": @"MiniMax-Text-01", @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"MiniMax-VL-01",   @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"abab6.5s-chat",   @"bidi": @NO, @"onlyBidi": @NO}
        ];
    }
    if ([ep containsString:@"anthropic"]) {
        return @[
            @{@"id": @"claude-sonnet-4-5",         @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"claude-3-7-sonnet-latest",  @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"claude-3-5-haiku-latest",   @"bidi": @NO, @"onlyBidi": @NO}
        ];
    }
    if ([ep containsString:@"x.ai"]) {
        return @[
            @{@"id": @"grok-3",             @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"grok-3-mini",        @"bidi": @NO, @"onlyBidi": @NO},
            @{@"id": @"grok-2-vision-1212", @"bidi": @NO, @"onlyBidi": @NO}
        ];
    }
    return @[];
}

#endif /* AGMultiModelProtocolAdapter_h */
