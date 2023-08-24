//
//  HealthCheck.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/3.
//

import SwiftUI

@available(*, deprecated) struct HealthCheckPage: View {
    @AppStorage("juzhudi", store: userDefaults) var juzhudi: String = ""
    @AppStorage("jinji_lxr", store: userDefaults) var jinji_lxr: String = ""
    @AppStorage("jinji_guanxi", store: userDefaults) var jinji_guanxi: String =
        ""
    @AppStorage("jiji_mobile", store: userDefaults) var jiji_mobile: String = ""

    func formData() -> [(
        caption: String, defaultString: String, value: Binding<String>
    )] {
        [
            ("居住地:", "安徽省合肥市蜀山区", $juzhudi), ("应急联系人:", "人名", $jinji_lxr),
            ("应急联系人关系:", "母亲/父亲/...", $jinji_guanxi),
            ("应急联系人电话:", "11位数字", $jiji_mobile),
        ]
    }

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(formData(), id: \.caption) { dataSection in
                        HStack {
                            Text(dataSection.caption)
                            Spacer()
                            TextField(
                                dataSection.defaultString,
                                text: dataSection.value
                            )
                        }
                    }
                }
                .scrollContentBackground(.hidden).scrollDisabled(true)
                .toolbar {
                    AsyncButton(bigStyle: false) {
                        _ = try await UstcWeixinClient.main.dailyReportHealth()
                    } label: { _ in
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .navigationBarTitle("Health Check", displayMode: .inline)
        }
    }
}

@available(*, deprecated) struct HealthCheckPage_Previews: PreviewProvider {
    static var previews: some View { HealthCheckPage() }
}
