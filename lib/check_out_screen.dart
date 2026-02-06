import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slcloudapppro/registered_customer_tab.dart';
import 'package:slcloudapppro/theme/app_colors.dart';
import 'package:slcloudapppro/walk_in_customer_tab.dart';

import 'Model/Product.dart';


class SalesInvoiceScreen extends StatefulWidget {
  final String invoiceMgrId;
  final List<Product> products;
  final Map<String, int> cart ;
  final List<Map<String, dynamic>> fbrList ;

  const SalesInvoiceScreen({
    Key? key,
    required this.invoiceMgrId,
    required this.products,
    required this.cart,
    required this.fbrList,
  }) : super(key: key);

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String invoiceMgrId ='';
  late final List<Map<String, dynamic>> fbrList ;



  // Cart data - shared between tabs
  Map<String, int> _cart = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    invoiceMgrId = widget.invoiceMgrId;
    _cart = widget.cart;
    fbrList = widget.fbrList;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inside your build method
    final double screenWidth = MediaQuery.of(context).size.width;
    const int tabCount = 2;
    final double tabWidth = screenWidth / tabCount;
    return Scaffold(
      backgroundColor: AppColors.appBackgroundGreyColor,
      appBar: AppBar(
        backgroundColor: AppColors.mainButtonsColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sales Invoice',
          style: TextStyle(
              color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),

      ),
      body: Column(
        children: [
          Container(
              margin: EdgeInsets.only(left: 20,right: 20,top: 10,bottom: 10),
              padding: EdgeInsets.all(5),
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  16.0,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    16.0,
                  ),
                  color: AppColors.mainButtonsColor,
                ),
                labelColor: Colors.black,
                unselectedLabelColor: AppColors.tabLabelBlueColor,
                labelStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                tabs:  [
                  Container(
                      width: tabWidth,
                      child: Tab(text: 'Walk-in')
                  ),
                  Container(
                      width: tabWidth,
                      child: Tab(text: 'Registered')
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                WalkInCustomerTab(
                  cart: _cart,
                  products: widget.products,
                  onCartUpdate: () => setState(() {}),
                  invoiceMgrId: widget.invoiceMgrId,
                ),
                RegisteredCustomerTab(
                  cart: _cart,
                  products: widget.products,
                  onCartUpdate: () => setState(() {}),
                  invoiceMgrId: widget.invoiceMgrId,
                  fbrList: fbrList,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

