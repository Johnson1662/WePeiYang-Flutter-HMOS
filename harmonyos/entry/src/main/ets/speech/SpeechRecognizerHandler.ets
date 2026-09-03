import { BusinessError } from '@kit.BasicServicesKit';
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { MethodCall, MethodCallHandler, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'SpeechRecognizerHandler';
const DOMAIN = 0x0000;

export class SpeechRecognizerHandler implements MethodCallHandler {
  private context: common.UIAbilityContext;
  private channel: MethodChannel;
  private asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private currentSessionId: string | null = null;
  private isListening: boolean = false;

  constructor(context: common.UIAbilityContext, channel: MethodChannel) {
    this.context = context;
    this.channel = channel;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    switch (call.method) {
      case 'requestPermission':
        await this.handleRequestPermission(result);
        break;
      case 'startListening':
        await this.handleStartListening(call, result);
        break;
      case 'stopListening':
        await this.handleStopListening(result);
        break;
      case 'cancelListening':
        await this.handleCancelListening(result);
        break;
      default:
        result.notImplemented();
    }
  }

  private async ensurePermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const tokenId = this.context.applicationInfo.accessTokenId;
      const grantStatus = atManager.checkAccessTokenSync(tokenId, 'ohos.permission.MICROPHONE');
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }
      const authResults = await atManager.requestPermissionsFromUser(this.context, ['ohos.permission.MICROPHONE']);
      if (authResults && authResults.authResults && authResults.authResults.length > 0) {
        return authResults.authResults[0] === 0;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Permission check/request failed: ${JSON.stringify(e)}`);
    }
    return false;
  }

  private async handleRequestPermission(result: MethodResult): Promise<void> {
    const granted = await this.ensurePermission();
    result.success(granted);
  }

  private async initEngine(): Promise<boolean> {
    if (this.asrEngine !== null) {
      return true;
    }
    return new Promise<boolean>((resolve) => {
      const extraParams: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'short' };
      const initParamsInfo: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 1,
        extraParams: extraParams
      };
      speechRecognizer.createEngine(initParamsInfo, (err: BusinessError, engine: speechRecognizer.SpeechRecognitionEngine) => {
        if (!err && engine) {
          hilog.info(DOMAIN, TAG, 'Succeeded in creating speechRecognizer engine');
          this.asrEngine = engine;
          this.setupListener();
          resolve(true);
        } else {
          hilog.error(DOMAIN, TAG, `Failed to create engine: ${err ? err.message : 'unknown'}`);
          resolve(false);
        }
      });
    });
  }

  private setupListener(): void {
    if (!this.asrEngine) return;
    const listener: speechRecognizer.RecognitionListener = {
      onStart: (sessionId: string, eventMessage: string) => {
        hilog.info(DOMAIN, TAG, `onStart, sessionId: ${sessionId}, msg: ${eventMessage}`);
      },
      onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
        hilog.info(DOMAIN, TAG, `onEvent, sessionId: ${sessionId}, code: ${eventCode}, msg: ${eventMessage}`);
      },
      onResult: (sessionId: string, res: speechRecognizer.SpeechRecognitionResult) => {
        hilog.info(DOMAIN, TAG, `onResult, sessionId: ${sessionId}, isFinal: ${res.isFinal}, text: ${res.result}`);
        this.channel.invokeMethod('onSpeechResult', {
          'text': res.result,
          'isFinal': res.isFinal
        });
      },
      onComplete: (sessionId: string, eventMessage: string) => {
        hilog.info(DOMAIN, TAG, `onComplete, sessionId: ${sessionId}, msg: ${eventMessage}`);
        this.isListening = false;
        this.currentSessionId = null;
        this.channel.invokeMethod('onSpeechComplete', {
          'message': eventMessage
        });
      },
      onError: (sessionId: string, errorCode: number, errorMessage: string) => {
        hilog.error(DOMAIN, TAG, `onError, sessionId: ${sessionId}, code: ${errorCode}, msg: ${errorMessage}`);
        this.isListening = false;
        this.currentSessionId = null;
        this.channel.invokeMethod('onSpeechError', {
          'code': errorCode,
          'message': errorMessage
        });
      }
    };
    this.asrEngine.setListener(listener);
  }

  private async handleStartListening(call: MethodCall, result: MethodResult): Promise<void> {
    const hasPermission = await this.ensurePermission();
    if (!hasPermission) {
      result.error('PERMISSION_DENIED', 'Microphone permission was denied by user', null);
      return;
    }

    const engineReady = await this.initEngine();
    if (!engineReady || !this.asrEngine) {
      result.error('ENGINE_INIT_FAILED', 'Failed to initialize speech recognition engine', null);
      return;
    }

    if (this.isListening && this.currentSessionId) {
      try {
        this.asrEngine.cancel(this.currentSessionId);
      } catch (e) {
        // ignore cancellation error
      }
      this.isListening = false;
    }

    const sessionId = `speech_${Date.now()}`;
    this.currentSessionId = sessionId;

    try {
      const audioParam: speechRecognizer.AudioInfo = {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      };
      const extraParam: Record<string, Object> = {
        'recognitionMode': 0, // 0 = 实时麦克风录音识别，由系统自动采集麦克风音频
        'vadBegin': 2000,
        'vadEnd': 3000,
        'maxAudioDuration': 60000
      };
      const recognizerParams: speechRecognizer.StartParams = {
        sessionId: sessionId,
        audioInfo: audioParam,
        extraParams: extraParam
      };

      this.asrEngine.startListening(recognizerParams);
      this.isListening = true;
      result.success(true);
    } catch (err) {
      const bErr = err as BusinessError;
      hilog.error(DOMAIN, TAG, `startListening exception: ${JSON.stringify(bErr)}`);
      this.isListening = false;
      this.currentSessionId = null;
      result.error(`${bErr.code ?? 1002200002}`, bErr.message ?? 'startListening failed', null);
    }
  }

  private async handleStopListening(result: MethodResult): Promise<void> {
    if (!this.isListening || !this.currentSessionId || !this.asrEngine) {
      this.isListening = false;
      this.currentSessionId = null;
      result.success(true);
      return;
    }

    try {
      this.asrEngine.finish(this.currentSessionId);
      result.success(true);
    } catch (err) {
      const bErr = err as BusinessError;
      hilog.error(DOMAIN, TAG, `stopListening exception: ${JSON.stringify(bErr)}`);
      result.error(`${bErr.code ?? 'STOP_FAILED'}`, bErr.message ?? 'stopListening failed', null);
    }
  }

  private async handleCancelListening(result: MethodResult): Promise<void> {
    if (this.currentSessionId && this.asrEngine) {
      try {
        this.asrEngine.cancel(this.currentSessionId);
      } catch (e) {
        // ignore
      }
    }
    this.isListening = false;
    this.currentSessionId = null;
    result.success(true);
  }

  destroy(): void {
    if (this.currentSessionId && this.asrEngine) {
      try {
        this.asrEngine.cancel(this.currentSessionId);
      } catch (e) {
        // ignore
      }
    }
    if (this.asrEngine) {
      try {
        this.asrEngine.shutdown();
      } catch (e) {
        // ignore
      }
      this.asrEngine = null;
    }
    this.isListening = false;
    this.currentSessionId = null;
  }
}
