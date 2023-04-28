//
//  CurriculumNewView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023-04-08.
//

import SwiftUI

struct CurriculumNewView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Today, 0408")
                .font(.title)
                .bold()

            VStack {
                Divider()
                Image(systemName: "arrowtriangle.down.fill")
            }
            .padding(.vertical)

            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { _ in
                    HStack {
                        Spacer(minLength: 350)
                        ForEach(0 ..< 50) { index in
                            VStack {
                                Text("!")
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 35, height: 35)
                            }
                            .tag(index)
                        }
                        Spacer()
                    }
                }
            }
            ForEach(Array(repeating: Course.example, count: 5)) { course in
                VStack(alignment: .leading) {
                    RectangleProgressBar(course: course)
                        .padding(.vertical, 2)
                        .padding(.horizontal)
                }
            }

            Spacer()
        }
        .navigationBarTitle("Curriculum", displayMode: .inline)
    }
}

struct CurriculumNewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CurriculumNewView()
        }
    }
}
