//
//  HealthCheck.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/3.
//

import SwiftSoup
import SwiftUI

struct HealthCheckPage: View {
    @AppStorage("juzhudi", store: userDefaults) var juzhudi: String = ""
    @AppStorage("jinji_lxr", store: userDefaults) var jinji_lxr: String = ""
    @AppStorage("jinji_guanxi", store: userDefaults) var jinji_guanxi: String = ""
    @AppStorage("jiji_mobile", store: userDefaults) var jiji_mobile: String = ""
    @State var status = AsyncViewStatus.inProgress
    @State var checked = false

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    HStack {
                        Text("居住地:")
                        Spacer()
                        TextField("安徽省合肥市蜀山区", text: $juzhudi)
                    }
                    HStack {
                        Text("应急联系人:")
                        Spacer()
                        TextField("人名", text: $jinji_lxr)
                    }
                    HStack {
                        Text("应急联系人关系:")
                        Spacer()
                        TextField("母亲/父亲/...", text: $jinji_guanxi)
                    }
                    HStack {
                        Text("应急联系人电话:")
                        Spacer()
                        TextField("11位数字", text: $jiji_mobile)
                    }
                }
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)

                Spacer()

                Button {
                    asyncBind($checked, status: $status) {
                        try await UstcWeixinClient.main.dailyReportHealth()
                    }
                } label: {
                    Text("Check")
                }
                .buttonStyle(BigButtonStyle())

                if checked {
                    Label("Status: Checked", systemImage: "checkmark")
                        .foregroundColor(.accentColor)
                } else {
                    Text("")
                }
            }
            .navigationBarTitle("Health Check", displayMode: .inline)
        }
    }
}

struct HealthCheckPage_Previews: PreviewProvider {
    static var previews: some View {
        HealthCheckPage()
    }
}
