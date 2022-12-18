//
//  SettingsView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct CASSettingsView: View {
    @AppStorage("passportUsername") var passportUsername: String = ""
    @AppStorage("passportPassword") var passportPassword: String = ""
    @State var showFailedAlert = false
    @State var showSuccessAlert = false
    enum Field: Int, Hashable {
        case username
        case password
    }
    @FocusState var foucusField: Field?
    var body: some View {
        NavigationStack {
            VStack {
                TitleAndSubTitle(title: "Input USTC CAS username & password",
                                 subTitle: "",
                                 style: .caption)
                
                Text("""
                        This service is brought to you by USTC CAS server, not this app.
                        For more information, see Settings > Legal > Disclaimer
                        """)
                .font(.caption)
                .foregroundColor(.secondary)
                .bold()
                
                Spacer()
                
                Form {
                    HStack {
                        Text("Username:")
                        Spacer()
                        TextField("Username", text: $passportUsername)
                            .focused($foucusField, equals: .username)
                            .onSubmit {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    foucusField = .password
                                }
                            }
                            .submitLabel(.next)
                            .keyboardType(.asciiCapable)
                        Spacer()
                    }
                    HStack {
                        Text("Password:")
                        Spacer()
                        SecureField("Password", text: $passportPassword)
                            .focused($foucusField, equals: .password)
                            .submitLabel(.done)
                            .onSubmit {
                                checkAndLogin()
                            }
                        Spacer()
                    }
                    Button(action: checkAndLogin, label: {Text("Check & Login")})
                }
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                Spacer()
            }
            .alert("Login Failed", isPresented: $showFailedAlert, actions: {}, message: {
                Text("Double check your username and password")
            })
            .alert("Login Success", isPresented: $showSuccessAlert, actions: {}, message: {
                Text("You're good to go")
            })
            .padding()
            .navigationTitle("CAS Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func checkAndLogin() {
        mainUstcCasClient = UstcCasClient(username: passportUsername, password: passportPassword)
        if mainUstcCasClient.checkLogined() {
            showSuccessAlert = true
        } else {
            showFailedAlert = true
        }
    }
}

extension Bundle {
    var releaseNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    var buildNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

struct AboutLifeAtUSTCView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                    .resizable()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(.secondary, lineWidth: 2))
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 15))
                    .contextMenu {
                        ShareLink(item: "Life@USTC") {
                            Label("Share this app", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            let url = URL(string: "https://www.pixiv.net/artworks/97582506")!
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Visit Icon original post", systemImage: "network")
                        }
                    }
                
                Text("Life@USTC")
                    .font(.title)
                    .bold()
                
                Text("Brought to you by @tiankaima")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                
                Text("Ver: \(Bundle.main.releaseNumber ?? "") build\(Bundle.main.buildNumber ?? "")")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Github")
                        .fontWeight(.semibold)
                        .font(.title2)
                        .padding([.top,.bottom],2)
                    Text("https://github.com/tiankaima/Life-USTC")
                    
                    Text("Twitter")
                        .fontWeight(.semibold)
                        .font(.title2)
                        .padding([.top,.bottom],2)
                    Text("https://twitter.com/tiankaima")
                }
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EmptyView: View {
    var body: some View {
        VStack {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 60))
                .frame(width: 100, height: 100)
                .foregroundColor(.yellow)
                .symbolRenderingMode(.hierarchical)
            Text("Comming Soon~")
                .font(.title2)
                .bold()
        }
    }
}

struct LegalInfoView: View {
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    VStack(alignment: .leading) {
                        Text("Icon source")
                        Text("Visit https://www.pixiv.net/artworks/97582506 for origin post, much thanks to original author.🥰")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("Feedkit source")
                        Text("Visit https://github.com/nmdias/FeedKit (MIT License) for origin repo, much thanks to original author.😘")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("USTC CAS DISCLAIMER:")
                        Text("""
This service is brought to you by USTC CAS server, not this app.
For more information and license agreement, checkout https://passport.ustc.edu.cn/
When dealing with your username and password, we only store it on your device and follow industry standards.
We use your username & password to skip the verification process on webpage/API services by validating the token in the background in a 15-minute cycle(if actively used). That means we simulate user's behaviour and send out requests as if they were sent by users. This doesn't viloate USTC CAS's License Agreement, but they are subject to change without pre-notice.
This process could potentially trigger warnings of USTC, and could potentially fail. In turn, We do NOT take any responsiblity and/or make any commitment about this feature's usability, USE THIS FEATURE AT YOUR OWN RISK.
""")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Legal")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingsView: View {
    @State var searchText = ""
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Feed Source Settings", destination: EmptyView())
                    NavigationLink("CAS Settings", destination: CASSettingsView())
                    NavigationLink("Change User Type", destination: EmptyView())
                    NavigationLink("Notification Settings", destination: EmptyView())
                }
                
                Section {
                    NavigationLink("About Life@USTC", destination: AboutLifeAtUSTCView())
                    NavigationLink("Legal Info", destination: LegalInfoView())
                }
            }
            .navigationTitle("Settings")
//            .searchable(text: $searchText, placement: .toolbar)
        }
    }
}
