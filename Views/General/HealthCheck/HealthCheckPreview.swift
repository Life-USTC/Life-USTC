//
//  HealthCheckPreview.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/3.
//

import SwiftUI

struct HealthCheckPreview: View {
    @ObservedObject var mainClient = UstcWeixinClient.main
    @State var status = AsyncViewStatus.inProgress
    @State var checked = false

    var body: some View {
        HStack {
            Image(systemName: "thermometer.medium")
                .font(.largeTitle)
                .foregroundColor(.accentColor)

            Spacer()

            VStack {
                if let lastReportedHealth = mainClient.lastReportedHealth {
                    Text("上次打卡时间: \(lastReportedHealth.formatted())")
                } else {
                    Text("未记录到上次打卡, 点此打卡")
                }

                if status == .success, checked {
                    Text("已完成打卡")
                        .foregroundColor(.accentColor)
                } else {
                    if status != .inProgress {
                        Text("Something went wrong")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .onAppear {
            if let lastReportedHealth = mainClient.lastReportedHealth {
                if lastReportedHealth.addingTimeInterval(60 * 60 * 8) > Date() {
                    return
                }
            }
            asyncBind($checked, status: $status) {
                try await UstcWeixinClient.main.dailyReportHealth()
            }
        }
        .onTapGesture {
            asyncBind($checked, status: $status) {
                try await UstcWeixinClient.main.dailyReportHealth()
            }
        }
        .padding()
    }
}

struct HealthCheckPreview_Previews: PreviewProvider {
    static var previews: some View {
        HealthCheckPreview()
    }
}
