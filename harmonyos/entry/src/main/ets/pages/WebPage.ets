import { webview } from '@kit.ArkWeb';
import router from '@ohos.router';

@Entry
@Component
struct WebPage {
  @State url: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const storedUrl = AppStorage.Get<string>('webViewUrl');
    if (storedUrl && storedUrl.length > 0) {
      AppStorage.Delete('webViewUrl');
      this.url = storedUrl;
    }
  }

  build() {
    Column() {
      Row() {
        Button() {
          Text('← 返回')
            .fontSize(16)
            .fontColor('#ffffff')
        }
        .backgroundColor('#1976D2')
        .borderRadius(20)
        .height(36)
        .padding({ left: 16, right: 16 })
        .margin({ left: 12, top: 8, bottom: 8 })
        .onClick(() => {
          router.back();
        })

        Blank()
      }
      .width('100%')
      .backgroundColor('#1a1a1a')

      if (this.url.length > 0) {
        Web({ src: this.url, controller: this.controller })
          .width('100%')
          .height('100%')
          .javaScriptAccess(true)
          .domStorageAccess(true)
      } else {
        Text('无页面地址')
          .width('100%')
          .height('100%')
          .textAlign(TextAlign.Center)
          .fontSize(16)
          .fontColor('#999999')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
  }
}
