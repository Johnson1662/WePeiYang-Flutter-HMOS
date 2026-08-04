/**
 * WePeiYang Schedule Service Widget Card.
 *
 * ArkUI service widget page displaying today's courses.
 * Layout hierarchy:
 *  ┌─────────────────────────┐
 *  │  📅 今日课表    第X周    │
 *  ├─────────────────────────┤
 *  │ █ 课程名                 │
 *  │   地点                   │
 *  │   08:30-10:05            │
 *  ├─────────────────────────┤
 *  │ █ 另一门课               │
 *  │   ...                    │
 *  └─────────────────────────┘
 *
 * Empty state:
 *  ┌─────────────────────────┐
 *  │  📅 今日课表    第X周    │
 *  │                         │
 *  │     今日无课 :)         │
 *  │                         │
 *  └─────────────────────────┘
 */

// Service widgets use @Entry + @Component but NOT @Reusable
@Entry
@Component
struct SDCFormCard {
  @StorageProp('courses') courses: object[] = [];
  @StorageProp('isEmpty') isEmpty: boolean = true;
  @StorageProp('lastUpdate') lastUpdate: number = 0;

  build() {
    Column() {
      // ── Header ──
      Row() {
        Text('课程表')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF');

        Blank();

        // Show "第X周" if there are courses, else "假期"
        Text(this.isEmpty ? '假期' : '')
          .fontSize(11)
          .fontColor('rgba(255, 255, 255, 0.7)');
      }
      .width('100%')
      .padding({ bottom: 8 });

      // ── Body ──
      if (this.isEmpty) {
        // Empty state (center the message)
        Column() {
          Text('今日无课 :)')
            .fontSize(14)
            .fontColor('rgba(255, 255, 255, 0.8)');
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        // Course list — use ForEach (supported in service widgets)
        ForEach(this.courses, (item: object, index: number) => {
          Row() {
            // Color bar (blue accent)
            Column()
              .width(3)
              .height('100%')
              .borderRadius({ topLeft: 2, bottomLeft: 2 })
              .backgroundColor('#3B82F6');

            Column() {
              // Course name
              Text((item as Record<string, Object>)['name'] as string)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });

              // Location (optional)
              if (((item as Record<string, Object>)['location'] as string).length > 0) {
                Text((item as Record<string, Object>)['location'] as string)
                  .fontSize(11)
                  .fontColor('rgba(255, 255, 255, 0.65)')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }

              // Time
              if (((item as Record<string, Object>)['time'] as string).length > 0) {
                Text((item as Record<string, Object>)['time'] as string)
                  .fontSize(11)
                  .fontColor('rgba(255, 255, 255, 0.65)');
              }
            }
            .layoutWeight(1)
            .padding({ left: 8 });
          }
          .width('100%')
          .padding(6)
          .backgroundColor('rgba(255, 255, 255, 0.08)')
          .borderRadius(6)
          .margin({ bottom: index < (this.courses.length - 1) ? 4 : 0 });
        }, (item: object, index: number) => index.toString());
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#1E293B')
    .borderRadius(12);
  }
}
