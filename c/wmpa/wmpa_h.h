

/* this ALWAYS GENERATED file contains the definitions for the interfaces */


 /* File created by MIDL compiler version 8.00.0595 */
/* at Sat Apr 13 02:30:51 2013
 */
/* Compiler settings for wmpa.odl:
    Oicf, W1, Zp8, env=Win32 (32b run), target_arch=X86 8.00.0595 
    protocol : dce , ms_ext, c_ext, robust
    error checks: allocation ref bounds_check enum stub_data 
    VC __declspec() decoration level: 
         __declspec(uuid()), __declspec(selectany), __declspec(novtable)
         DECLSPEC_UUID(), MIDL_INTERFACE()
*/
/* @@MIDL_FILE_HEADING(  ) */

#pragma warning( disable: 4049 )  /* more than 64k source lines */


/* verify that the <rpcndr.h> version is high enough to compile this file*/
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of <rpcndr.h>
#endif // __RPCNDR_H_VERSION__


#ifndef __wmpa_h_h__
#define __wmpa_h_h__

#if defined(_MSC_VER) && (_MSC_VER >= 1020)
#pragma once
#endif

/* Forward Declarations */ 

#ifndef __IWMPADIALOG_FWD_DEFINED__
#define __IWMPADIALOG_FWD_DEFINED__
typedef interface IWMPADIALOG IWMPADIALOG;

#endif 	/* __IWMPADIALOG_FWD_DEFINED__ */


#ifndef __WMPADIALOG_FWD_DEFINED__
#define __WMPADIALOG_FWD_DEFINED__

#ifdef __cplusplus
typedef class WMPADIALOG WMPADIALOG;
#else
typedef struct WMPADIALOG WMPADIALOG;
#endif /* __cplusplus */

#endif 	/* __WMPADIALOG_FWD_DEFINED__ */


#ifdef __cplusplus
extern "C"{
#endif 



#ifndef __Wmpa_LIBRARY_DEFINED__
#define __Wmpa_LIBRARY_DEFINED__

/* library Wmpa */
/* [version][uuid] */ 


DEFINE_GUID(LIBID_Wmpa,0x2D225385,0xEFD3,0x4DD8,0x93,0x77,0xA7,0xF2,0x44,0xC5,0x22,0xD0);

#ifndef __IWMPADIALOG_DISPINTERFACE_DEFINED__
#define __IWMPADIALOG_DISPINTERFACE_DEFINED__

/* dispinterface IWMPADIALOG */
/* [uuid] */ 


DEFINE_GUID(DIID_IWMPADIALOG,0x01C1B3AA,0xC7FC,0x4023,0x89,0xA5,0xC8,0x14,0xE1,0xB6,0x2B,0x9B);

#if defined(__cplusplus) && !defined(CINTERFACE)

    MIDL_INTERFACE("01C1B3AA-C7FC-4023-89A5-C814E1B62B9B")
    IWMPADIALOG : public IDispatch
    {
    };
    
#else 	/* C style interface */

    typedef struct IWMPADIALOGVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )( 
            IWMPADIALOG * This,
            /* [in] */ REFIID riid,
            /* [annotation][iid_is][out] */ 
            _COM_Outptr_  void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )( 
            IWMPADIALOG * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )( 
            IWMPADIALOG * This);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfoCount )( 
            IWMPADIALOG * This,
            /* [out] */ UINT *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetTypeInfo )( 
            IWMPADIALOG * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo **ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE *GetIDsOfNames )( 
            IWMPADIALOG * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR *rgszNames,
            /* [range][in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE *Invoke )( 
            IWMPADIALOG * This,
            /* [annotation][in] */ 
            _In_  DISPID dispIdMember,
            /* [annotation][in] */ 
            _In_  REFIID riid,
            /* [annotation][in] */ 
            _In_  LCID lcid,
            /* [annotation][in] */ 
            _In_  WORD wFlags,
            /* [annotation][out][in] */ 
            _In_  DISPPARAMS *pDispParams,
            /* [annotation][out] */ 
            _Out_opt_  VARIANT *pVarResult,
            /* [annotation][out] */ 
            _Out_opt_  EXCEPINFO *pExcepInfo,
            /* [annotation][out] */ 
            _Out_opt_  UINT *puArgErr);
        
        END_INTERFACE
    } IWMPADIALOGVtbl;

    interface IWMPADIALOG
    {
        CONST_VTBL struct IWMPADIALOGVtbl *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IWMPADIALOG_QueryInterface(This,riid,ppvObject)	\
    ( (This)->lpVtbl -> QueryInterface(This,riid,ppvObject) ) 

#define IWMPADIALOG_AddRef(This)	\
    ( (This)->lpVtbl -> AddRef(This) ) 

#define IWMPADIALOG_Release(This)	\
    ( (This)->lpVtbl -> Release(This) ) 


#define IWMPADIALOG_GetTypeInfoCount(This,pctinfo)	\
    ( (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo) ) 

#define IWMPADIALOG_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    ( (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo) ) 

#define IWMPADIALOG_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    ( (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) ) 

#define IWMPADIALOG_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    ( (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) ) 

#endif /* COBJMACROS */


#endif 	/* C style interface */


#endif 	/* __IWMPADIALOG_DISPINTERFACE_DEFINED__ */


DEFINE_GUID(CLSID_WMPADIALOG,0x9007B1B4,0x0006,0x453D,0xA7,0x99,0xDB,0x8C,0xBA,0x1A,0xE2,0x2A);

#ifdef __cplusplus

class DECLSPEC_UUID("9007B1B4-0006-453D-A799-DB8CBA1AE22A")
WMPADIALOG;
#endif
#endif /* __Wmpa_LIBRARY_DEFINED__ */

/* Additional Prototypes for ALL interfaces */

/* end of Additional Prototypes */

#ifdef __cplusplus
}
#endif

#endif


