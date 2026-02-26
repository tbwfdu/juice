import SwiftUI

struct CustomRoundedCorners: InsettableShape {
	var radius: CGFloat
	var corners: Corner
	var insetAmount: CGFloat = 0

	func path(in rect: CGRect) -> Path {
		let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
		let r = min(radius, insetRect.width / 2, insetRect.height / 2)
		let path = CGPath(
			roundedRect: insetRect,
			cornerWidth: r,
			cornerHeight: r,
			transform: nil
		)

		var roundedPath = Path(path)
		if corners != [.allCorners] {
			// Mask out corners not included by rebuilding per-corner.
			var p = Path()
			let minX = insetRect.minX
			let maxX = insetRect.maxX
			let minY = insetRect.minY
			let maxY = insetRect.maxY

		let tl = corners.contains(.topLeft) ? r : 0
		let tr = corners.contains(.topRight) ? r : 0
		let bl = corners.contains(.bottomLeft) ? r : 0
		let br = corners.contains(.bottomRight) ? r : 0

			p.move(to: CGPoint(x: minX, y: maxY - bl))
			if bl > 0 {
				p.addQuadCurve(
					to: CGPoint(x: minX + bl, y: maxY),
					control: CGPoint(x: minX, y: maxY)
				)
			} else {
				p.addLine(to: CGPoint(x: minX, y: maxY))
			}
			p.addLine(to: CGPoint(x: maxX - br, y: maxY))
			if br > 0 {
				p.addQuadCurve(
					to: CGPoint(x: maxX, y: maxY - br),
					control: CGPoint(x: maxX, y: maxY)
				)
			} else {
				p.addLine(to: CGPoint(x: maxX, y: maxY))
				p.addLine(to: CGPoint(x: maxX, y: maxY))
			}
			p.addLine(to: CGPoint(x: maxX, y: minY + tr))
			if tr > 0 {
				p.addQuadCurve(
					to: CGPoint(x: maxX - tr, y: minY),
					control: CGPoint(x: maxX, y: minY)
				)
			} else {
				p.addLine(to: CGPoint(x: maxX, y: minY))
			}
			p.addLine(to: CGPoint(x: minX + tl, y: minY))
			if tl > 0 {
				p.addQuadCurve(
					to: CGPoint(x: minX, y: minY + tl),
					control: CGPoint(x: minX, y: minY)
				)
			} else {
				p.addLine(to: CGPoint(x: minX, y: minY))
			}
			p.addLine(to: CGPoint(x: minX, y: maxY - bl))
			roundedPath = p
		}

		return roundedPath
	}

	func inset(by amount: CGFloat) -> some InsettableShape {
		var copy = self
		copy.insetAmount += amount
		return copy
	}
}

extension CustomRoundedCorners {
	struct Corner: OptionSet {
		let rawValue: Int

		static let topLeft = Corner(rawValue: 1 << 0)
		static let topRight = Corner(rawValue: 1 << 1)
		static let bottomLeft = Corner(rawValue: 1 << 2)
		static let bottomRight = Corner(rawValue: 1 << 3)
		static let allCorners: Corner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
	}
}
