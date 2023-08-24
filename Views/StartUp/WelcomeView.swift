//
//  WelcomeView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023-05-01.
//

import SwiftUI

struct WelcomeView_1: View {
    @State var showText = false
    var textToShow =
        "Want to see course table\n&\nexam arrangement in one place?"
    var imageName = "Example.HomeView"
    var nextView: () -> AnyView = { AnyView(WelcomeView_2()) }

    let circleRadius = 40.0
    var nextPageHint: some View {
        VStack(alignment: .trailing) {
            Spacer()
            Text(textToShow).font(.system(.largeTitle, design: .monospaced))
                .foregroundColor(.black).padding().background(Color.white)
                .overlay(Rectangle().stroke(.black)).padding(.horizontal)
                .frame(maxWidth: .infinity)

            NavigationLink {
                nextView()
            } label: {
                Image(systemName: "arrow.right").font(.largeTitle).bold()
                    .foregroundColor(.black).padding()
                    .background {
                        Circle().stroke().fill(.black)
                        Circle().fill(.white)
                    }
                    .frame(width: circleRadius * 2, height: circleRadius * 2)
            }
        }
        .shadow(radius: 50).padding(.bottom, 100)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(imageName).resizable()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .overlay {
                        if showText {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .overlay { RoundedRectangle(cornerRadius: 30).stroke() }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 1.5)) {
                            showText.toggle()
                        }
                    }

                if showText { nextPageHint }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
        }
        .ignoresSafeArea().navigationBarBackButtonHidden()
    }
}

struct WelcomeView_2: View {
    @State var isPresented = true
    var body: some View {
        USTCCASLoginView(
            title: "To get your course table...",
            isInSheet: true,
            casLoginSheet: $isPresented
        )
        .navigationDestination(
            isPresented: .init(
                get: { !isPresented },
                set: { isPresented = !$0 }
            )
        ) { WelcomeView_3() }
        .navigationBarBackButtonHidden()
    }
}

struct WelcomeView_3: View {
    var body: some View {
        WelcomeView_1(
            textToShow:
                "Want to the latest info from school with system notification?",
            imageName: "Example.Notification",
            nextView: { AnyView(EmptyView()) }
        )
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { WelcomeView_1() }
        NavigationStack { WelcomeView_2() }
    }
}
