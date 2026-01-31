//
//  GradientHeaderBar.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 25/1/2026.
//
import SwiftUI


struct GradientHeaderBar: View {
	enum BackgroundStyle {
		case gradient
		case clear
	}

    var title: String = "Juice"
	var backgroundStyle: BackgroundStyle = .gradient

    var body: some View {
		VStack(alignment: .leading) {
			backgroundView
            Text(title)
				.font(.system(size: 40, weight: .bold, design: .default))
				.foregroundStyle(.primary)
				.padding(.leading, 150)
				//.padding(5)
				.tracking(-2)
				//.frame(height: .infinity, alignment: .trailing)
        }
        //.frame(maxWidth: .infinity)
		.frame(
			minHeight: 40,
			maxHeight: 40,
			//alignment: .init(horizontal: .leading, vertical: .top)
		)
		//.padding(.bottom, 20)
		
//        .overlay(
//            Rectangle()
//                .fill(Color.black.opacity(0.12))
//                .frame(height: 1),
//            alignment: .bottom
//        )
		//.ignoresSafeArea(edges: .all)
    }

	@ViewBuilder
	private var backgroundView: some View {
		switch backgroundStyle {
		case .gradient:
			LinearGradient.juice
		case .clear:
			Color.clear
		}
	}
}

#Preview("GradientHeaderBar - Gradient") {
    GradientHeaderBar(title: "Juice", backgroundStyle: .gradient)
}

#Preview("GradientHeaderBar - Clear") {
    GradientHeaderBar(title: "Juice", backgroundStyle: .clear)
}

