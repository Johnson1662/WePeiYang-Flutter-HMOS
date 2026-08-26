const formStorage = new LocalStorage();

@Entry(formStorage)
@Component
struct SDCFormCard {
  @LocalStorageProp('courses') courses: object[] = [];
  @LocalStorageProp('isEmpty') isEmpty: boolean = true;

  build() {
    Column() {
      Row() {
        Text('课程表')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF');
        Blank();
        Text(this.isEmpty ? '假期' : '今日安排')
          .fontSize(11)
          .fontColor('rgba(255, 255, 255, 0.8)');
      }
      .width('100%')
      .padding({ bottom: 8 });

      if (this.isEmpty || this.courses.length === 0) {
        Column() {
          Text('今天没有课程啦，\n假期愉快！')
            .fontSize(13)
            .fontColor('rgba(255, 255, 255, 0.9)')
            .textAlign(TextAlign.Center)
            .lineHeight(20);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        Column() {
          ForEach(this.courses, (item: object, index: number) => {
            Row() {
              Column()
                .width(4)
                .height(36)
                .borderRadius(2)
                .backgroundColor('#2563EB');
              Column() {
                Text((item as Record<string, Object>)['name'] as string)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
                Row() {
                  Text((item as Record<string, Object>)['location'] as string)
                    .layoutWeight(1)
                    .fontSize(11)
                    .fontColor('rgba(255, 255, 255, 0.7)')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                  Text((item as Record<string, Object>)['time'] as string)
                    .fontSize(11)
                    .fontColor('rgba(255, 255, 255, 0.7)')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ left: 6 });
                }
                .width('100%')
                .margin({ top: 2 });
              }
              .layoutWeight(1)
              .padding({ left: 8, right: 4 });
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 6, bottom: 6 })
            .backgroundColor('rgba(255, 255, 255, 0.12)')
            .borderRadius(10)
            .margin({ bottom: index === this.courses.length - 1 ? 0 : 5 });
          }, (item: object, index: number) => index.toString());
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('#1E293B')
    .borderRadius(16);
  }
}
