//
//  WelcomeView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023-05-01.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack {
            Group {
                HStack {
                    Image("Icon")
                        .resizable()
                        .clipShape(Circle())
                        .frame(width: 50, height: 50)
                        .overlay {
                            Circle()
                                .stroke(Color.blue)
                        }
                    Text("Life@USTC")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Text("Everything you need in USTC")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.bold)
            }
        }
        .padding()
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WelcomeView()
        }
    }
}
