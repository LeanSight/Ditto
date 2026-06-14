#include "stdafx.h"
#include "ClipFormatQListCtrl.h"
#include "BitmapHelper.h"
#include "CP_Main.h"
#include <afxmt.h>   // CCriticalSection / CSingleLock

CClipFormatQListCtrl::CClipFormatQListCtrl(void)
{
	m_counter = 0;
	m_clipRow = -1;
	m_convertedToSmallImage = false;
}

CClipFormatQListCtrl::~CClipFormatQListCtrl(void)
{
}


HGLOBAL CClipFormatQListCtrl::GetDibFittingToHeight(CDC *pDc, int height)
{
	if(m_cfType != CF_DIB &&
		m_cfType != theApp.m_PNG_Format)
	{
		return NULL;
	}

	// The background pre-cache thread and the UI paint thread both call this for the same
	// clip. Without a lock they both Free()+realloc m_hgData concurrently (the flag was set
	// before the convert finished), so one thread read half-freed data and the preview
	// rendered as corrupted/garbled bands on scroll. Serialize the whole convert so one
	// thread finishes (cache valid, flag set) before the other reads it.
	static CCriticalSection s_convertCS;
	CSingleLock lock(&s_convertCS, TRUE);

	if(m_convertedToSmallImage)
	{
		return m_hgData;
	}

	CBitmap Bitmap;
	if( !CBitmapHelper::GetCBitmap(this, pDc, &Bitmap, height) )
	{
		Bitmap.DeleteObject();
		// the data is useless, so free it.
		this->Free();
		m_convertedToSmallImage = true;   // mark so we don't retry the useless data
		return NULL;
	}

	this->m_autoDeleteData = true;

	// delete the large image data loaded from the db
	this->Free();

	this->m_autoDeleteData = false;

	//Convert the smaller bitmap back to a dib
	HPALETTE hPal = NULL;
	this->m_hgData = CBitmapHelper::hBitmapToDIB((HBITMAP)Bitmap, BI_RGB, hPal);

	// Mark cached only AFTER the new data is in place, so a concurrent reader never sees the
	// flag set while m_hgData is mid-free/realloc.
	m_convertedToSmallImage = true;

	return this->m_hgData;
}
