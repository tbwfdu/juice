//
//  FlowLayout.swift
//  Juice
//
//  Created by Pete Lindley on 28/1/2026.
//
import SwiftUI


struct FlowLayout: Layout {
	enum RowAlignment {
		case leading
		case center
		case trailing
	}

    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8
	var rowAlignment: RowAlignment = .leading

	private struct Row {
		let startIndex: Int
		let count: Int
		let width: CGFloat
		let height: CGFloat
	}

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = size.width
            if x > 0 && x + itemWidth > maxWidth {
                // wrap to next row
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += itemWidth + (x > 0 ? spacing : 0)
        }

        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxX = bounds.maxX
		let minX = bounds.minX
		let y = bounds.minY
        var rowHeight: CGFloat = 0
		var rows: [Row] = []
		var currentRowStart = 0
		var currentRowWidth: CGFloat = 0
		var currentRowCount = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = size.width
            let itemHeight = size.height

			let nextWidth = currentRowCount == 0
				? itemWidth
				: currentRowWidth + spacing + itemWidth

			if currentRowCount > 0 && minX + nextWidth > maxX {
				rows.append(
					Row(
						startIndex: currentRowStart,
						count: currentRowCount,
						width: currentRowWidth,
						height: rowHeight
					)
				)
				currentRowStart = index
				currentRowCount = 0
				currentRowWidth = 0
				rowHeight = 0
			}

			currentRowWidth = currentRowCount == 0
				? itemWidth
				: currentRowWidth + spacing + itemWidth
			currentRowCount += 1
			rowHeight = max(rowHeight, itemHeight)
        }

		if currentRowCount > 0 {
			rows.append(
				Row(
					startIndex: currentRowStart,
					count: currentRowCount,
					width: currentRowWidth,
					height: rowHeight
				)
			)
		}

		var rowIndex = 0
		var yOffset = y
		for row in rows {
			let available = max(0, bounds.width - row.width)
			let rowInset: CGFloat
			switch rowAlignment {
			case .leading:
				rowInset = 0
			case .center:
				rowInset = available / 2
			case .trailing:
				rowInset = available
			}
			var x = bounds.minX + rowInset

			for i in 0..<row.count {
				let subview = subviews[row.startIndex + i]
				let size = subview.sizeThatFits(.unspecified)
				let itemWidth = size.width
				let itemHeight = size.height

				subview.place(
					at: CGPoint(x: x, y: yOffset),
					proposal: ProposedViewSize(width: itemWidth, height: itemHeight)
				)

				x += itemWidth + spacing
			}

			yOffset += row.height + rowSpacing
			rowIndex += 1
		}
    }
}
