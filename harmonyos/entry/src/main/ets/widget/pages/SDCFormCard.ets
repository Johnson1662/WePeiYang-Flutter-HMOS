const formStorage = new LocalStorage();

@Entry(formStorage)
@Component
struct SDCFormCard {
  @LocalStorageProp('courses') courses: object[] = [];
  @LocalStorageProp('isEmpty') isEmpty: boolean = true;
  // 系统在添加卡片时注入当前卡片尺寸，如 "2*2"、"2*4"、"4*4"
  @LocalStorageProp('formDimension') formDimension: string = '2*4';

  /** 4*4 大卡片展示更多课程，2*2 紧凑卡片最多 1 门 */
  private maxCourseCount(): number {
    if (this.formDimension === '4*4') {
      return 4;
    }
    if (this.formDimension === '2*2') {
      return 1;
    }
    return 2;
  }

  build() {
    Column() {
      Row() {
        Text('课程表')
          .fontSize(this.formDimension === '4*4' ? 22 : 18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF');
        Blank();
        Text(this.isEmpty ? '假期' : '今日安排')
          .fontSize(this.formDimension === '4*4' ? 13 : 11)
          .fontColor('rgba(255, 255, 255, 0.8)');
      }
      .width('100%')
      .padding({ bottom: this.formDimension === '4*4' ? 12 : 8 });

      if (this.isEmpty || this.courses.length === 0) {
        Column() {
          Text('今天没有课程啦，\n假期愉快！')
            .fontSize(this.formDimension === '4*4' ? 16 : 13)
            .fontColor('rgba(255, 255, 255, 0.9)')
            .textAlign(TextAlign.Center)
            .lineHeight(this.formDimension === '4*4' ? 24 : 20);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        Column() {
          ForEach(
            this.courses.slice(0, this.maxCourseCount()),
            (item: object, index: number) => {
              Row() {
                Column()
                  .width(4)
                  .height(this.formDimension === '4*4' ? 42 : 36)
                  .borderRadius(2)
                  .backgroundColor('#2563EB');
                Column() {
                  Text((item as Record<string, Object>)['name'] as string)
                    .fontSize(this.formDimension === '4*4' ? 15 : 13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                  Row() {
                    Text((item as Record<string, Object>)['location'] as string)
                      .layoutWeight(1)
                      .fontSize(this.formDimension === '4*4' ? 13 : 11)
                      .fontColor('rgba(255, 255, 255, 0.7)')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                    Text((item as Record<string, Object>)['time'] as string)
                      .fontSize(this.formDimension === '4*4' ? 13 : 11)
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
              .margin({
                bottom: index === this.courses.slice(0, this.maxCourseCount()).length - 1 ? 0 : 5
              });
            },
            (item: object, index: number) => index.toString()
          );
          if (this.courses.length > this.maxCourseCount()) {
            Text(`等 ${this.courses.length} 门课程`)
              .fontSize(11)
              .fontColor('rgba(255, 255, 255, 0.6)')
              .margin({ top: 4 });
          }
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
    .borderRadius(16)
    .onClick(() => {
      // 点击卡片直达课表页；路由参数在 EntryAbility 侧转发给 Flutter
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { 'route': 'schedule/course' }
      });
    });
  }
}
