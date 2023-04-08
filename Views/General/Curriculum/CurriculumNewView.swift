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
                        ForEach(0 ..< 50) { index in
                            VStack {
                                Text("!")
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 35, height: 35)
                            }
                            .tag(index)
                        }
                    }
                }
            }

            List {
                ForEach(Array(repeating: Course.example, count: 5)) { course in
                    VStack(alignment: .leading) {
                        Text(course.clockTime)
                            .bold()
                        Text(course.name)
                            .fontWeight(.light)
                            .font(.title3)
                    }
                }
            }
            .listStyle(.grouped)
            .scrollContentBackground(.hidden)

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
