const formStorage = new LocalStorage();

@Entry(formStorage)
@Component
struct SDCFormCard {
  @LocalStorageProp('courses') courses: object[] = [];
  @LocalStorageProp('isEmpty') isEmpty: boolean = true;

  build() {
    const weekdayShort: string[] = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const weekdayChinese: string[] = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    const day: number = new Date().getDay();
    const weekdayIndex: number = day === 0 ? 6 : day - 1;
    const visibleCourses: object[] = this.courses.slice(0, 2);
    const remainingCount: number = this.courses.length > 2 ? this.courses.length - 2 : 0;

    Column() {
      // ── Header ──
      Row() {
        Column() {
          Text(weekdayShort[weekdayIndex] + '.')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .maxLines(1);
          Text(weekdayChinese[weekdayIndex])
            .fontSize(10)
            .fontColor('rgba(255, 255, 255, 0.8)')
            .margin({ top: -4 });
        }
        .alignItems(HorizontalAlign.Start);

        Blank();

        Row() {
          Text('微北洋')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF');
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('rgba(255, 255, 255, 0.22)')
        .borderRadius(12);
      }
      .width('100%')
      .padding({ bottom: 6 });

      // ── Content ──
      if (this.isEmpty || this.courses.length === 0) {
        Column() {
          Text('这两天都没有课程啦，\n假期愉快！')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('rgba(255, 255, 255, 0.95)')
            .textAlign(TextAlign.Center)
            .lineHeight(18);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        Column() {
          ForEach(visibleCourses, (item: object, index: number) => {
            Row() {
              // Left blue vertical accent bar
              Column()
                .width(4)
                .height(36)
                .borderRadius(2)
                .backgroundColor('#2563EB');

              Column() {
                Text((item as Record<string, Object>)['name'] as string)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#0F172A')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });

                Row() {
                  if (((item as Record<string, Object>)['location'] as string).length > 0 &&
                      (item as Record<string, Object>)['location'] as string !== '————') {
                    Text((item as Record<string, Object>)['location'] as string)
                      .layoutWeight(1)
                      .fontSize(11)
                      .fontColor('#475569')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                  if (((item as Record<string, Object>)['time'] as string).length > 0) {
                    Text((item as Record<string, Object>)['time'] as string)
                      .fontSize(11)
                      .fontColor('#475569')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ left: 6 });
                  }
                }
                .width('100%')
                .margin({ top: 2 });
              }
              .layoutWeight(1)
              .padding({ left: 8, right: 4 });
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 6, bottom: 6 })
            .backgroundColor('rgba(255, 255, 255, 0.94)')
            .borderRadius(10)
            .margin({ bottom: index === visibleCourses.length - 1 && remainingCount === 0 ? 0 : 5 });
          }, (item: object, index: number) => index.toString());

          if (remainingCount > 0) {
            Text('今天还有 ' + remainingCount + ' 个课程')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor('rgba(255, 255, 255, 0.85)')
              .margin({ top: 2, left: 2 });
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
    .linearGradient({
      angle: 135,
      colors: [
        ['#1D4ED8', 0.0],
        ['#3B82F6', 0.5],
        ['#60A5FA', 1.0]
      ]
    })
    .borderRadius(16);
  }
}

