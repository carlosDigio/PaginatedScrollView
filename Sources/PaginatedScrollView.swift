import UIKit

public protocol PaginatedScrollViewDataSource: AnyObject {
	func numberOfPagesInPaginatedScrollView(_ paginatedScrollView: PaginatedScrollView) -> Int
	func paginatedScrollView(_ paginatedScrollView: PaginatedScrollView, controllerAtIndex index: Int) -> UIViewController
}

public protocol PaginatedScrollViewDelegate: AnyObject {
	func paginatedScrollView(_ paginatedScrollView: PaginatedScrollView, didMoveToIndex index: Int)
	func paginatedScrollView(_ paginatedScrollView: PaginatedScrollView, willMoveFromIndex index: Int)
}

open class PaginatedScrollView: UIScrollView {
	open weak var viewDataSource: PaginatedScrollViewDataSource?
	open weak var viewDelegate: PaginatedScrollViewDelegate?
	
	private weak var parentController: UIViewController?
	private var currentPage: Int
	private var shouldEvaluatePageChange = false
	private var pageBeforeDrag: Int = 0
	private var willMoveNotified = false
	private var lastBoundsSize: CGSize = .zero
	private let pageTagOffset = 1000
	private var needsConfigure = false

	public init(frame: CGRect, parentController: UIViewController, initialPage: Int) {
		self.parentController = parentController
		currentPage = initialPage

		super.init(frame: frame)

		isPagingEnabled = true
		scrollsToTop = false
		showsHorizontalScrollIndicator = false
		showsVerticalScrollIndicator = false

		delegate = self
		autoresizingMask = [.flexibleWidth, .flexibleHeight]
		backgroundColor = .clear
	}

	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	open func configure() {
		guard bounds.size.width > 0, bounds.size.height > 0 else {
			needsConfigure = true
			setNeedsLayout()
			return
		}

		needsConfigure = false
		guard let parent = parentController else { return }
		parent.children.forEach { child in
			child.willMove(toParent: nil)
			child.view.removeFromSuperview()
			child.removeFromParent()
		}

		let numPages = viewDataSource?.numberOfPagesInPaginatedScrollView(self) ?? 0
		contentSize = CGSize(width: bounds.size.width * CGFloat(numPages), height: bounds.size.height)

		loadScrollViewWithPage(currentPage - 1)
		loadScrollViewWithPage(currentPage)
		loadScrollViewWithPage(currentPage + 1)
		gotoPage(currentPage, animated: false)
	}

	public func goToNextPage(animated: Bool) {
		let numPages = viewDataSource?.numberOfPagesInPaginatedScrollView(self) ?? 0
		let newPage = currentPage + 1
		guard newPage < numPages else { return }
		viewDelegate?.paginatedScrollView(self, willMoveFromIndex: currentPage)
		let previousPage = currentPage
		gotoPage(newPage, animated: animated)
		currentPage = newPage
		if !animated {
			viewDelegate?.paginatedScrollView(self, didMoveToIndex: newPage)
		} else {
			pageBeforeDrag = previousPage
		}
	}

	public func goToPreviousPage(animated: Bool) {
		let newPage = currentPage - 1
		guard newPage >= 0 else { return }
		viewDelegate?.paginatedScrollView(self, willMoveFromIndex: currentPage)
		let previousPage = currentPage
		gotoPage(newPage, animated: animated)
		currentPage = newPage
		if !animated {
			viewDelegate?.paginatedScrollView(self, didMoveToIndex: newPage)
		} else {
			pageBeforeDrag = previousPage
		}
	}

	public func goToPage(_ page: Int, animated: Bool) {
		guard page != currentPage else { return }
		viewDelegate?.paginatedScrollView(self, willMoveFromIndex: currentPage)
		let previousPage = currentPage
		gotoPage(page, animated: animated)
		currentPage = page
		if !animated {
			viewDelegate?.paginatedScrollView(self, didMoveToIndex: page)
		} else {
			pageBeforeDrag = previousPage
		}
	}
}
 
// MARK: - Private methods
private extension PaginatedScrollView {
	func gotoPage(_ page: Int, animated: Bool) {
		loadScrollViewWithPage(page - 1)
		loadScrollViewWithPage(page)
		loadScrollViewWithPage(page + 1)

		var bounds = self.bounds
		bounds.origin.x = bounds.size.width * CGFloat(page)
		bounds.origin.y = 0
		scrollRectToVisible(bounds, animated: animated)
	}
	
	func loadScrollViewWithPage(_ page: Int) {
		let numPages = viewDataSource?.numberOfPagesInPaginatedScrollView(self) ?? 0
		if page >= numPages || page < 0 {
			return
		}

		if let controller = viewDataSource?.paginatedScrollView(self, controllerAtIndex: page), controller.view.superview == nil {
			var frame = self.bounds
			frame.origin.x = frame.size.width * CGFloat(page)
			frame.origin.y = 0
			controller.view.frame = frame
			controller.view.tag = pageTagOffset + page

			parentController?.addChild(controller)
			addSubview(controller.view)
			controller.didMove(toParent: parentController)
		}
	}
}

// MARK: - UIScrollViewDelegate
extension PaginatedScrollView: UIScrollViewDelegate {
	public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
		pageBeforeDrag = currentPage
		willMoveNotified = false
		shouldEvaluatePageChange = true
	}

	public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		shouldEvaluatePageChange = false
		willMoveNotified = false
		notifyPageChangeFinished()
	}

	public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
		guard pageBeforeDrag != currentPage else { return }
		notifyPageChangeFinished()
		pageBeforeDrag = currentPage
	}

	public func scrollViewDidScroll(_ scrollView: UIScrollView) {
		if shouldEvaluatePageChange {
			let pageWidth = bounds.size.width
			let page = Int(floor((contentOffset.x - pageWidth / 2) / pageWidth) + 1)
			if page != currentPage {
				if !willMoveNotified {
					viewDelegate?.paginatedScrollView(self, willMoveFromIndex: pageBeforeDrag)
					willMoveNotified = true
				}
			}
			currentPage = page

			loadScrollViewWithPage(page - 1)
			loadScrollViewWithPage(page)
			loadScrollViewWithPage(page + 1)
		}
	}

	private func notifyPageChangeFinished() {
		let pageWidth = bounds.size.width
		guard pageWidth > 0 else { return }
		let page = Int(floor((contentOffset.x - pageWidth / 2) / pageWidth) + 1)
		guard page != pageBeforeDrag else { return }
		viewDelegate?.paginatedScrollView(self, didMoveToIndex: page)
	}
}

// MARK: - Layout
extension PaginatedScrollView {
	override open func layoutSubviews() {
		super.layoutSubviews()

		if needsConfigure, bounds.size.width > 0, bounds.size.height > 0 {
			configure()
			return
		}

		let newSize = bounds.size
		guard newSize != lastBoundsSize else { return }
		lastBoundsSize = newSize

		let numPages = viewDataSource?.numberOfPagesInPaginatedScrollView(self) ?? 0
		contentSize = CGSize(width: newSize.width * CGFloat(numPages), height: newSize.height)

		for subview in subviews {
			let page = subview.tag - pageTagOffset
			guard page >= 0 && page < numPages else { continue }
			var frame = bounds
			frame.origin.x = frame.size.width * CGFloat(page)
			frame.origin.y = 0
			subview.frame = frame
		}

		gotoPage(currentPage, animated: false)
	}
}
