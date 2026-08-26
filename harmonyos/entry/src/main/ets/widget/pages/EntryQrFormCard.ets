const entryQrFormStorage = new LocalStorage();

@Entry(entryQrFormStorage)
@Component
struct EntryQrFormCard {
  @LocalStorageProp('qrContent') qrContent: string = '';
  @LocalStorageProp('status') status: string = '正在读取入校码';

  build() {
    Stack() {
      if (this.qrContent.length > 0) {
        QRCode(this.qrContent)
          .width('100%')
          .aspectRatio(1)
          .backgroundColor(Color.White)
          .padding(8);
      } else {
        Column() {
          Text(this.status)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(16)
        .backgroundColor('#1D4ED8');
      }
    }
    .width('100%')
    .height('100%')
    .padding(8)
    .backgroundColor('#1D4ED8')
    .borderRadius(16);
  }
}
