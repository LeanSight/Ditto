// BitmapHelper.h: interface for the CBitmapHelper class.
//
//////////////////////////////////////////////////////////////////////

#if !defined(AFX_BITMAPHELPER_H__641D941B_5487_4F85_BFC1_012F2083A8B6__INCLUDED_)
#define AFX_BITMAPHELPER_H__641D941B_5487_4F85_BFC1_012F2083A8B6__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#define IS_WIN30_DIB(lpbi)  ((*(LPDWORD)(lpbi)) == sizeof(BITMAPINFOHEADER))

#include "clip.h"

class CBitmapHelper
{
public:
	CBitmapHelper();
	virtual ~CBitmapHelper();

	static int		GetCBitmapWidth(const CBitmap& cbm);
	static int		GetCBitmapHeight(const CBitmap& cbm);
	static BOOL		GetCBitmap(void* pClip2, CDC* pDC, CBitmap* pBitMap, int nMaxHeight);
	static BOOL		GetCBitmap(CClipFormats& clips, CDC* pDC, CBitmap* pBitMap, BOOL horizontal);
	static HANDLE	hBitmapToDIB(HBITMAP hBitmap, DWORD dwCompression, HPALETTE hPal);
	static WORD		PaletteSize(LPSTR lpDIB);
	static WORD		DIBNumColors(LPSTR lpDIB);
	static bool		DrawDIB(CDC* pDC, HANDLE hData, int nLeft, int nRight, int& nWidth);
	// Win+V-style image card: COVER-fill rc (fill width+height, center-crop the overflow) from an
	// already-decoded, cached DIB (the one GetDibFittingToHeight returns). Uses StretchDIBits on
	// the cached bits — it never re-decodes the clip, so it is race-safe with the background
	// pre-cache thread (re-decoding per paint corrupted previews on scroll).
	static BOOL		DrawDibCover(CDC* pDC, HANDLE hData, const CRect& rc, int cornerRadius = 0);

};

#endif // !defined(AFX_BITMAPHELPER_H__641D941B_5487_4F85_BFC1_012F2083A8B6__INCLUDED_)
