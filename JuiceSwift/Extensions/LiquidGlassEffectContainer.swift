//
//  LiquidGlassEffectContainer.swift
//  Juice
//
//  Created by Pete Lindley on 30/1/2026.
//


import SwiftUI

struct LiquidGlassEffectContainer: View {
    var body: some View {
		if #available(macOS 26.0, *) {
			GlassEffectContainer(spacing: 50) {
				PhaseAnimator([false, false,true ,false]) { morph in
					HStack(spacing: morph ? 50.0 : -15.0) {
						Button {
							//
						} label: {
							Image(systemName: "scribble.variable")
						}
						.padding()
						.glassEffect()
                        
						Button {
							//
						} label: {
							Image(systemName: "eraser.fill")
						}
						.padding()
						.glassEffect()
					}
					.tint(.green)
					.font(.system(size: 64.0))
				} animation: { morph in
					//.bouncy(duration: 2, extraBounce: 0.5)
					//.easeOut(duration: 2)
						.easeInOut(duration: 2)
						.repeatCount(0)
					//.timingCurve(0.68, -0.6, 0.32, 1.6, duration: 2)
                        
				}
			}
		} else {
			// Fallback on earlier versions
		}
    }
}

#Preview {
    LiquidGlassEffectContainer()
        .preferredColorScheme(.dark)
}
