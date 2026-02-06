import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PaymentMethodSection extends StatelessWidget {
  final String selectedPayment;
  final Function(String) onPaymentSelected;

  const PaymentMethodSection({
    super.key,
    required this.selectedPayment,
    required this.onPaymentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAYMENT METHOD',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.tabLabelBlueColor,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: const [
            // Wrapped in Builder to access parameters
          ],
        ),

        Row(
          children: [
            _PaymentOption(
              id: 'Cash',
              icon: Icons.payments_outlined,
              label: 'Cash',
              selectedPayment: selectedPayment,
              onTap: onPaymentSelected,
            ),

            const SizedBox(width: 16),

            _PaymentOption(
              id: 'Card',
              icon: Icons.credit_card_outlined,
              label: 'Card',
              selectedPayment: selectedPayment,
              onTap: onPaymentSelected,
            ),

            const SizedBox(width: 16),

            _PaymentOption(
              id: 'split',
              icon: Icons.account_balance_outlined,
              label: 'Split',
              selectedPayment: selectedPayment,
              onTap: onPaymentSelected,
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String id;
  final IconData icon;
  final String label;
  final String selectedPayment;
  final Function(String) onTap;

  const _PaymentOption({
    required this.id,
    required this.icon,
    required this.label,
    required this.selectedPayment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = selectedPayment == id;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onTap(id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainButtonsColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: isSelected ? Colors.black : AppColors.tabLabelBlueColor,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

