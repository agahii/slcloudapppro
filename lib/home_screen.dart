import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/Model/Product.dart';
import 'api_service.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String firstName = '';
  String lastName = '';
  final ScrollController _scrollController = ScrollController();final List<Product> _products = [];
  bool isLoading = false;
  int currentPage = 1;
  bool hasMore = true;
  final int pageSize = 20;
  final String managerID = '67e98001-1084-48ad-ba98-7d48c440e972';

  @override
  void initState() {
    super.initState();
    loadUserData();
    fetchProducts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 &&
          !isLoading &&
          hasMore) {
        fetchProducts();
      }
    });
  }
  Future<void> fetchProducts() async {
    setState(() => isLoading = true);

    try {
      final newProducts = await ApiService.fetchProducts(
        managerID: managerID,
        page: currentPage,
        pageSize: pageSize,
      );
      print('Received ${newProducts.length} products');
      setState(() {
        currentPage++;
        _products.addAll(newProducts);
        if (newProducts.length < pageSize) hasMore = false;
      });
    } catch (e) {
      print('Error loading products: $e');
    }

    setState(() => isLoading = false);
  }
  Widget _buildProductItem(Product product) {
    return ListTile(
      title: Text(product.skuName),
      subtitle: Text('Code: ${product.skuCode} | Brand: ${product.brandName}'),
      trailing: Text('Rs. ${product.tradePrice}'),
    );
  }
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();


    setState(() {
      firstName = prefs.getString('firstName') ?? '';
      lastName = prefs.getString('lastName') ?? '';
    });
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: theme.primaryColor,
              ),
              accountName: Text('$firstName $lastName'),
              accountEmail: const Text(''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  firstName.isNotEmpty ? firstName[0] : '',
                  style: TextStyle(
                    fontSize: 40,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: theme.iconTheme.color),
              title: const Text('Logout'),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.centerLeft,
            child: Text(
              'Welcome, $firstName $lastName!',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
            ),
          ),
          const Divider(),
          Expanded(
            child: _products.isEmpty
                ? Center(child: isLoading ? CircularProgressIndicator() : Text('No products found.'))
                : ListView.builder(
              controller: _scrollController,
              itemCount: _products.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _products.length) {
                  return _buildProductItem(_products[index]);
                } else {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
          ),

        ],
      ),
    );
  }

}
