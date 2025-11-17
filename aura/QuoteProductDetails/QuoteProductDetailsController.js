({
	doinit : function(cmp, event, helper) {
        var inlineEditing = false;
		var editCost = cmp.get('v.canCost');
        var editPrice = cmp.get('v.canPrice');
        var editVendor = cmp.get('v.canVendor');
        var detailLines = cmp.get('v.productHeader.details');
        
        cmp.set('v.detailColumns', [
            {label: 'Validation', fieldName: '',  type: 'button-icon', typeAttributes: {iconName: {fieldName: 'iconName'}, 
                                                                  alternativeText: {fieldName: 'errorMessage'},  alignment: 'center'}},
            {label: 'Quote Line', fieldName: 'quoteLineName', type: 'text', wrapText: true},
            {label: 'Component', fieldName: 'componentType', type: 'text', wrapText: true},
            {label: '', fieldName: 'costCurrencyCode', type: 'text', wrapText: false, cellAttributes: {alignment: 'center'}},
            {label: 'Cost', fieldName: 'vendorCost', type: 'text', editable: inlineEditing, typeAttributes: {maximumFractionDigits:'6'}, cellAttributes: {alignment: 'right'}},
            {label: 'Cost UOM', fieldName: 'costUOM', type: 'text', editable: inlineEditing},
            {label: '', fieldName: 'priceCurrencyCode', type: 'text', wrapText: false, cellAttributes: {alignment: 'center'}},
            {label: 'Price', fieldName: 'customerPrice', type: 'text', editable: inlineEditing, typeAttributes: {maximumFractionDigits:'6'}, cellAttributes: {alignment: 'right'}},
            {label: 'Price UOM', fieldName: 'priceUOM', type: 'text', editable: inlineEditing},
            {label: 'Start Date', fieldName: 'componentStartDate', type: 'date', typeAttributes: {
                day: 'numeric',
                month: 'numeric',
                year: 'numeric'
            }, editable: inlineEditing, wrapText: true},
            {label: 'End Date', fieldName: 'componentEndDate', type: 'date', typeAttributes: {
                day: 'numeric',
                month: 'numeric',
                year: 'numeric'
            }, editable: inlineEditing, wrapText: true}
        ]);   
        var product1 = cmp.get("v.productHeader");
        console.log("v.productHeader"+JSON.stringify(product1));
        console.log("product1"+product1.quoteID);
        
	},
    SIDDetails : function(cmp, event) {
        var product = cmp.get('v.productHeader');
        var name = event.getSource().get('v.name');
        cmp.set('v.componentType', name);
        cmp.set('v.showSIDModal', 'true');
    },
    serviceScheduler: function(cmp, event, helper){
        console.log('here');
        cmp.set('v.componentType', 'serviceSchedulerComponent');
        cmp.set('v.showSIDModal', 'true');
    },
    saveChanges : function(cmp, event) {
        
    },
    handleRowAction: function(cmp, event, helper){
        var row = event.getParam( 'row' );
        console.log('row==>'+JSON.stringify(row));
        if(row.errorMessage!=null && row.errorMessage!=''){
            var title='Error';
            var type="error";
            if(row.iconName=='utility:check'){
                title='Success';
                type='success';
            }
            helper.showToast(event, type, title, row.errorMessage);
        }
    },
    closeModal: function(cmp) {
        cmp.set('v.showSIDModal', false);
    },
    closeDetail: function(cmp) {
        var closeModalEvent = cmp.getEvent('CloseModalEvent');
        closeModalEvent.setParams({
            "showModal" : "false"
        });
        closeModalEvent.fire();
    }
    
})