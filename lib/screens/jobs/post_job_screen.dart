import 'dart:async';

import '../../models/api_models.dart';
import '../../core/api/api_exception.dart';
import '../profile/plans_screen.dart';
import '../profile/kyc_screen.dart';
import 'ai_credits_screen.dart';
import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/location_map.dart';
import 'package:employer_kariger_app/widgets/searchable_option_sheet.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key, this.job});
  final EmployerJob? job;
  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

/// Tells the jobs list to open Drafts while the server safety check is queued.
enum JobPostResult { checking }

class _PostJobScreenState extends State<PostJobScreen> {
  Widget _wizardStepper() {
    const labels = [
      'Work & pay',
      'Karigar profile',
      'Shift & interview',
      'Preview & publish',
    ];
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: List.generate(
          4,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 3 ? 0 : 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: (widget.job != null || index <= _step)
                    ? () => setState(() => _step = index)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: index == _step
                              ? AppColors.primary
                              : index < _step
                              ? AppColors.brand200
                              : AppColors.line2,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        labels[index],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.05,
                          fontWeight: index == _step
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: index == _step
                              ? AppColors.foreground
                              : index < _step
                              ? AppColors.brandDark
                              : AppColors.muted2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wizardCard({required Widget child}) => SizedBox(
    width: double.infinity,
    child: Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  Widget _savedJobPrompt() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.brand50,
      border: Border.all(color: AppColors.brand200),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(LucideIcons.history, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finish your saved job “${titleController.text}”?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${wageMinController.text.isEmpty ? '₹—' : '₹${wageMinController.text}'} – '
                '${wageMaxController.text.isEmpty ? '₹—' : '₹${wageMaxController.text}'} · '
                '${city ?? 'Location'} · ${openingsController.text.isEmpty ? '1' : openingsController.text} karigars',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () =>
                        setState(() => _showSavedJobPrompt = false),
                    child: const Text('Continue it'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const PostJobScreen()),
                    ),
                    child: const Text('Start fresh'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _stepOneContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (editingDraft && _showSavedJobPrompt) ...[
        _savedJobPrompt(),
        const SizedBox(height: 14),
      ],
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Job title', required: true),
            _JobTitlePicker(
              controller: titleController,
              profiles: jobProfiles,
              onProfileSelected: _selectJobProfile,
              onAddOwnTitle: _addOwnTitle,
              hasError: _fieldErrors.containsKey('title'),
            ),
            if (_fieldErrors['title'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _fieldErrors['title']!,
                  style: const TextStyle(color: AppColors.rose, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            const _Hint('Pick from the list, or add your own title.'),
            const SizedBox(height: 16),
            const _Label('Craft / category', required: true),
            _Select(
              _otherCategorySelected
                  ? 'Other (not in the list)'
                  : category ?? 'Select a craft',
              onTap: _chooseCategory,
              errorText: _fieldErrors['category'],
            ),
            const SizedBox(height: 16),
            const _Label('How many karigars do you need?', required: true),
            SizedBox(
              width: 204,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _fieldErrors.containsKey('openings')
                        ? AppColors.rose
                        : AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _stepperButton('−', () {
                      final n = int.tryParse(openingsController.text) ?? 1;
                      setState(
                        () => openingsController.text = '${n > 1 ? n - 1 : 1}',
                      );
                    }),
                    Expanded(
                      child: TextField(
                        controller: openingsController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: '1',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    _stepperButton('+', () {
                      final n = int.tryParse(openingsController.text) ?? 0;
                      setState(() => openingsController.text = '${n + 1}');
                    }),
                  ],
                ),
              ),
            ),
            if (_fieldErrors['openings'] != null)
              _InlineFieldError(_fieldErrors['openings']!),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.mapPin, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Where is the work?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('State', required: true),
                      _Select(
                        state ?? 'Select state',
                        onTap: () =>
                            _choose('Select state', states, _loadCities),
                        errorText: _fieldErrors['state'],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('City', required: true),
                      _Select(
                        city ?? 'Pick state first',
                        onTap: state == null
                            ? null
                            : () => _choose('Select city', cities, (v) {
                                setState(() {
                                  city = v;
                                  selectedLocation = null;
                                });
                                unawaited(_pinFromEnteredLocation());
                              }, citySearch: true),
                        errorText: _fieldErrors['city'],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Label('Address'),
            _Input(
              hint: 'Shop / building, street, area',
              controller: addressController,
              onChanged: _schedulePinFromAddress,
              onSubmitted: (_) {
                _pinFromEnteredLocation();
              },
            ),
            const SizedBox(height: 8),
            const _Hint(
              'Where the karigar comes to work. The map pin follows it.',
            ),
            const SizedBox(height: 16),
            const _Label('Pin on the map'),
            SizedBox(
              height: 220,
              child: LocationMap(
                key: ValueKey(
                  '$state/$city/${selectedLocation?.latitude}/${selectedLocation?.longitude}',
                ),
                initialLocation:
                    selectedLocation ?? const LatLng(22.5937, 78.9629),
                initialZoom: selectedLocation == null ? 4 : 14,
                hasSelection: selectedLocation != null,
                onLocationChanged: (point) =>
                    unawaited(_syncLocationFromMap(point)),
              ),
            ),
            Text(
              selectedLocation == null
                  ? 'The pin is on the centre of ${city ?? 'the selected city'}. Drag it, or tap the map, to the exact spot.'
                  : 'Pin set for this work location. Drag it, or tap the map, to adjust it.',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.indianRupee, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Pay',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Monthly pay (₹)'),
            Row(
              children: [
                Expanded(
                  child: _Input(
                    hint: '₹ From',
                    controller: wageMinController,
                    number: true,
                    errorText: _fieldErrors['wage'],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Input(
                    hint: '₹ To',
                    controller: wageMaxController,
                    number: true,
                    errorText: _fieldErrors['wage'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Bonus / incentive on top',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Per-piece rate, overtime, festival bonus…'),
              value: givesIncentive,
              onChanged: (v) => setState(() => givesIncentive = v),
            ),
            if (givesIncentive)
              Column(
                children: [
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _Input(
                          hint: '₹ Up to / month',
                          controller: incentiveMaxController,
                          number: true,
                          errorText: _fieldErrors['incentive'],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Input(
                          hint: 'For, e.g. Overtime',
                          controller: incentiveTypeController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _singleChips(
                    const [
                      'Per-piece rate',
                      'Overtime',
                      'Performance bonus',
                      'Festival bonus',
                      'Commission',
                    ],
                    incentiveTypeController.text,
                    (value) =>
                        setState(() => incentiveTypeController.text = value),
                  ),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text(
                  'Note for karigars',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 7),
                Text('(optional)', style: TextStyle(color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 8),
            _Input(
              hint: 'e.g. Must know silk embroidery. Bring your own scissors.',
              controller: otherRequirementsController,
              lines: 4,
              maxLength: 500,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: otherRequirementsController,
                builder: (_, value, __) => Text(
                  '${value.text.length}/500',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _stepperButton(String label, VoidCallback onTap) => SizedBox(
    width: 58,
    child: Material(
      color: AppColors.background,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ),
  );

  Widget _profileChoice({
    required String text,
    required bool selected,
    required VoidCallback onTap,
    bool usual = false,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(selected ? 24 : 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand50 : AppColors.card,
          border: Border.all(
            color: selected ? AppColors.brand200 : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(selected ? 24 : 10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.muted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (selected && usual) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.greenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'USUAL',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _stepTwoContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.greenBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '✨ Filled in with what most craft jobs ask. Change anything that doesn’t fit.',
          style: TextStyle(color: AppColors.green),
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Experience'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _profileChoice(
                  text: 'Anyone',
                  selected: experienceLevel == 'any',
                  usual: true,
                  onTap: () => setState(() => experienceLevel = 'any'),
                ),
                _profileChoice(
                  text: 'Freshers',
                  selected: experienceLevel == 'freshers',
                  onTap: () => setState(() => experienceLevel = 'freshers'),
                ),
                _profileChoice(
                  text: 'Experienced',
                  selected: experienceLevel == 'experienced',
                  onTap: () => setState(() => experienceLevel = 'experienced'),
                ),
              ],
            ),
            if (experienceLevel == 'experienced')
              Row(
                children: [
                  Expanded(
                    child: _Input(
                      hint: 'Min years',
                      controller: experienceController,
                      number: true,
                      errorText: _fieldErrors['experienceMin'],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Input(
                      hint: 'Max years',
                      controller: experienceMaxController,
                      number: true,
                      errorText: _fieldErrors['experienceMax'],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            const _Label('Who can apply'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _profileChoice(
                  text: 'Men & women',
                  selected: (gender ?? 'both') == 'both',
                  usual: true,
                  onTap: () => setState(() => gender = 'both'),
                ),
                _profileChoice(
                  text: 'Men',
                  selected: gender == 'male',
                  onTap: () => setState(() => gender = 'male'),
                ),
                _profileChoice(
                  text: 'Women',
                  selected: gender == 'female',
                  onTap: () => setState(() => gender = 'female'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Label('English'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _profileChoice(
                  text: 'Basic',
                  selected: english == 'basic',
                  usual: true,
                  onTap: () => setState(() => english = 'basic'),
                ),
                _profileChoice(
                  text: 'Good',
                  selected: english == 'good',
                  onTap: () => setState(() => english = 'good'),
                ),
                _profileChoice(
                  text: 'Fluent',
                  selected: english == 'fluent',
                  onTap: () => setState(() => english = 'fluent'),
                ),
              ],
            ),
            const _Hint('Most craft jobs need only Basic.'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.locateFixed, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Get karigars from',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _feeChoice(
              selected: reach == 'nearby',
              title: 'Nearby',
              detail: 'Karigars living close to the work. You set the range.',
              onTap: () => setState(() => reach = 'nearby'),
            ),
            const SizedBox(height: 10),
            _feeChoice(
              selected: reach == 'city',
              title: 'From a city',
              detail: 'Karigars living in the city you pick.',
              onTap: () => setState(() => reach = 'city'),
            ),
            if (reach == 'nearby') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Range'),
                  const Spacer(),
                  Text('within $reachKm km'),
                ],
              ),
              Slider(
                value: reachKm.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                onChanged: (v) => setState(() => reachKm = v.round()),
              ),
            ] else ...[
              const Divider(height: 30),
              const _Label('Which city?', required: true),
              _Input(
                hint: 'Type a city name',
                controller: reachCityController,
                onChanged: _searchReachCity,
                onTap: _showReachCitySuggestions,
                errorText: _fieldErrors['reachCity'],
              ),
              if (_reachCitySearching)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Searching…',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else if (_reachCityMatches.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _reachCityMatches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final match = _reachCityMatches[index];
                      return ListTile(
                        dense: true,
                        title: Text('${match['city']}'),
                        trailing: Text(
                          '${match['state']}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        onTap: () => _pickReachCity(match),
                      );
                    },
                  ),
                ),
              if (city != null)
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.brand50,
                    foregroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => setState(() {
                    reachCity = city;
                    reachState = state;
                    reachCityController.text = city!;
                  }),
                  child: Text('Same as the job: $city'),
                ),
              const _Hint(
                'Karigars living anywhere in this city see the job and get its alert.',
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Karigars from other cities who will move to ${city ?? 'this city'}?',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _profileChoice(
                  text: 'Yes, allow',
                  selected: relocationAllowed,
                  onTap: () => setState(() => relocationAllowed = true),
                ),
                _profileChoice(
                  text: 'No, local only',
                  selected: !relocationAllowed,
                  onTap: () => setState(() => relocationAllowed = false),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.sparkles, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Skills',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _chips(skills, selectedSkills, multi: true),
            _addSkillField(),
            const _Hint(
              'Tap the skills the karigar must know, or add your own.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.listFilter, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'More filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 8),
                Text('(optional)', style: TextStyle(color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Add these only if they really matter — each one leaves some karigars out.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterToggle(
                  _showAgeFilter ? '✓ Age' : '+ Age',
                  _showAgeFilter,
                  _toggleAgeFilter,
                ),
                _filterToggle(
                  _showLanguagesFilter ? '✓ Languages' : '+ Languages',
                  _showLanguagesFilter,
                  _toggleLanguageFilter,
                ),
                _filterToggle(
                  _showAssetsFilter ? '✓ Must have' : '+ Must have',
                  _showAssetsFilter,
                  _toggleAssetsFilter,
                ),
              ],
            ),
            if (_showAgeFilter) ...[
              const SizedBox(height: 16),
              const _Label('Age'),
              Row(
                children: [
                  Expanded(
                    child: _Input(
                      hint: 'Min age (18)',
                      controller: ageMinController,
                      number: true,
                      errorText: _fieldErrors['ageMin'],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Input(
                      hint: 'Max age (70)',
                      controller: ageMaxController,
                      number: true,
                      errorText: _fieldErrors['ageMax'],
                    ),
                  ),
                ],
              ),
            ],
            if (_showLanguagesFilter) ...[
              const Divider(height: 30),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Languages they speak',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove language filter',
                    onPressed: _toggleLanguageFilter,
                    icon: const Icon(LucideIcons.x, size: 20),
                  ),
                ],
              ),
              _chipsWithCustom(const [
                'Hindi',
                'English',
                'Tamil',
                'Telugu',
                'Kannada',
                'Malayalam',
                'Marathi',
                'Bengali',
                'Gujarati',
                'Punjabi',
                'Odia',
                'Urdu',
              ], selectedLanguages),
              const SizedBox(height: 10),
              _addOwnFilter(
                hint: 'Add another language',
                controller: customLanguageController,
                selected: selectedLanguages,
              ),
            ],
            if (_showAssetsFilter) ...[
              const Divider(height: 30),
              const Text(
                'They must have',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _chipsWithCustom(const [
                'Aadhaar card',
                'PAN card',
                'Bank account',
                'Smartphone',
                'Bike',
                'Driving licence',
                'Own tools',
              ], selectedAssets),
              const SizedBox(height: 10),
              _addOwnFilter(
                hint: 'Add another requirement',
                controller: customAssetController,
                selected: selectedAssets,
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _filterToggle(String label, bool selected, VoidCallback onTap) =>
      _Choice(text: label, selected: selected, onTap: onTap);

  void _toggleAgeFilter() => setState(() {
    _showAgeFilter = !_showAgeFilter;
    if (!_showAgeFilter) {
      ageMinController.clear();
      ageMaxController.clear();
    }
  });

  void _toggleLanguageFilter() => setState(() {
    _showLanguagesFilter = !_showLanguagesFilter;
    if (!_showLanguagesFilter) selectedLanguages.clear();
  });

  void _toggleAssetsFilter() => setState(() {
    _showAssetsFilter = !_showAssetsFilter;
    if (!_showAssetsFilter) selectedAssets.clear();
  });

  Widget _addOwnFilter({
    required String hint,
    required TextEditingController controller,
    required Set<String> selected,
  }) => Row(
    children: [
      Expanded(
        child: _Input(
          hint: hint,
          controller: controller,
          onSubmitted: (value) => _saveOwnFilter(value, controller, selected),
        ),
      ),
      const SizedBox(width: 8),
      TextButton(
        onPressed: () => _saveOwnFilter(controller.text, controller, selected),
        child: const Text('Add'),
      ),
    ],
  );

  void _saveOwnFilter(
    String value,
    TextEditingController controller,
    Set<String> selected,
  ) {
    final entered = value.trim();
    if (entered.isEmpty) return;
    final isLanguage = identical(controller, customLanguageController);
    final defaults = isLanguage
        ? const [
            'Hindi',
            'English',
            'Tamil',
            'Telugu',
            'Kannada',
            'Malayalam',
            'Marathi',
            'Bengali',
            'Gujarati',
            'Punjabi',
            'Odia',
            'Urdu',
          ]
        : const [
            'Aadhaar card',
            'PAN card',
            'Bank account',
            'Smartphone',
            'Bike',
            'Driving licence',
            'Own tools',
            'ITI / training certificate',
          ];
    final normalized = defaults.firstWhere(
      (item) => item.toLowerCase() == entered.toLowerCase(),
      orElse: () => entered,
    );
    final maxLength = isLanguage ? 30 : 40;
    if (normalized.length > maxLength || selected.length >= 15) {
      _message(
        isLanguage
            ? 'Add up to 15 languages, with 30 characters each.'
            : 'Add up to 15 requirements, with 40 characters each.',
      );
      return;
    }
    setState(() {
      selected.add(normalized);
      controller.clear();
    });
  }

  Widget _addSkillField() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _Input(
            hint: 'Add a skill',
            controller: customSkillController,
            onSubmitted: _saveSkill,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.brand50,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _saveSkill(customSkillController.text),
            child: const Text(
              'Add',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );

  void _saveSkill(String value) {
    final skill = value.trim();
    if (skill.isEmpty || skill.length > 50 || selectedSkills.length >= 30)
      return;
    setState(() {
      skills = {...skills, skill}.toList();
      selectedSkills.add(skill);
      customSkillController.clear();
    });
  }

  Widget _addPerkField() => Row(
    children: [
      Expanded(
        child: _Input(
          hint: 'Add your own, e.g. ESI',
          controller: perkController,
          onSubmitted: _savePerk,
        ),
      ),
      const SizedBox(width: 8),
      TextButton(
        onPressed: () => _savePerk(perkController.text),
        child: const Text('Add'),
      ),
    ],
  );

  void _savePerk(String value) {
    final perk = value.trim();
    if (perk.isEmpty || perk.length > 40 || selectedPerks.length >= 15) return;
    setState(() {
      perks = {...perks, perk}.toList();
      selectedPerks.add(perk);
      perkController.clear();
    });
  }

  String get _expiryDateLabel {
    final value = expiresAt;
    if (value == null) return 'Pick a date';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  Future<void> _pickExpiryDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: expiresAt == null || expiresAt!.isBefore(today)
          ? today.add(const Duration(days: 1))
          : expiresAt!,
      firstDate: DateTime(today.year, today.month, today.day + 1),
      lastDate: DateTime(today.year + 2),
    );
    if (date != null && mounted) setState(() => expiresAt = date);
  }

  String _assetBodyValue(String asset) =>
      const {
        'Aadhaar card': 'aadhaar',
        'PAN card': 'pan',
        'Bank account': 'bank_account',
        'Smartphone': 'smartphone',
        'Bike': 'bike',
        'Driving licence': 'driving_licence',
        'Own tools': 'own_tools',
        'ITI / training certificate': 'iti_training_certificate',
      }[asset] ??
      asset;

  Future<void> _pickInterviewTime({required bool start}) async {
    final current = _parseTime(
      start ? interviewStartController.text : interviewEndController.text,
    );
    final selected = await _chooseTime(
      current ??
          (start
              ? const TimeOfDay(hour: 11, minute: 0)
              : const TimeOfDay(hour: 16, minute: 0)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      final value = _formatTime(selected);
      if (start) {
        interviewStartController.text = value;
      } else {
        interviewEndController.text = value;
      }
    });
  }

  Widget _wizardTimeField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    String? errorText,
  }) {
    final time = _parseTime(controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: const Icon(LucideIcons.clock3, size: 19),
              errorText: errorText,
            ),
            child: Text(
              time == null ? 'Select time' : time.format(context),
              style: TextStyle(
                color: time == null ? AppColors.muted : AppColors.foreground,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _feeChoice({
    required bool selected,
    required String title,
    required String detail,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand50 : AppColors.card,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? LucideIcons.circleDot : LucideIcons.circle,
              color: selected ? AppColors.primary : AppColors.line,
              size: 25,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _stepThreeContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.clock3, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Working hours',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _Label('Shift'),
            _singleChips(
              ['Day', 'Night', 'Rotational', 'Flexible'],
              shift,
              _changeShift,
            ),
            if (shift == 'Day' || shift == 'Night') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _wizardTimeField(
                      label: 'From',
                      controller: shiftStartController,
                      onTap: () => _pickTime(start: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _wizardTimeField(
                      label: 'To',
                      controller: shiftEndController,
                      onTap: () => _pickTime(start: false),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            const _Label('Working days'),
            _dayChips(workDays),
            const _Hint(
              'Give the real timings and days, or karigars may not join.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.house, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Where will the karigar work?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _WorkInterviewCard(
              workMode: workMode,
              workModes: workModes,
              onWorkModeChanged: (v) => setState(() => workMode = v),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.calendarDays, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Interview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _Label('Interview days'),
            _dayChips(interviewDays),
            Row(
              children: [
                Expanded(
                  child: _wizardTimeField(
                    label: 'From',
                    controller: interviewStartController,
                    onTap: () => _pickInterviewTime(start: true),
                    errorText: _fieldErrors['interviewTime'],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _wizardTimeField(
                    label: 'To',
                    controller: interviewEndController,
                    onTap: () => _pickInterviewTime(start: false),
                    errorText: _fieldErrors['interviewTime'],
                  ),
                ),
              ],
            ),
            if (workMode != 'remote') ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('The interview is at the work address'),
                value: _interviewAtWork,
                onChanged: (value) =>
                    setState(() => _interviewAtWork = value ?? true),
              ),
              if (!_interviewAtWork)
                _Input(
                  hint: 'Office / shop address, with a landmark',
                  controller: interviewAddressController,
                ),
            ] else
              const _Hint('The interview is on a phone or video call.'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.gift, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Perks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _chipsWithCustom(perks, selectedPerks),
            const SizedBox(height: 10),
            _addPerkField(),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(LucideIcons.walletCards, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Does the karigar pay anything?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            _feeChoice(
              selected: !requiresWorkerFee,
              title: 'No — free to join',
              detail:
                  'The job shows a “No fee” badge. Karigars trust these more.',
              onTap: () => setState(() => requiresWorkerFee = false),
            ),
            _feeChoice(
              selected: requiresWorkerFee,
              title: 'Yes — the karigar pays a fee',
              detail:
                  'For a security deposit or uniform charge. The amount shows on the job.',
              onTap: () => setState(() => requiresWorkerFee = true),
            ),
            if (requiresWorkerFee)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 24),
                  _Input(
                    hint: '₹ Fee amount',
                    controller: workerFeeAmountController,
                    number: true,
                    errorText: _fieldErrors['fee'],
                  ),
                  const SizedBox(height: 10),
                  const _Label('What is it for?'),
                  _singleChips(
                    const [
                      'Uniform / T-shirt / bag',
                      'Tools / kit',
                      'Security deposit',
                      'Training fee',
                      'Exam fee',
                      'Documentation',
                      'Other',
                    ],
                    workerFeePurposeController.text,
                    (value) => setState(
                      () => workerFeePurposeController.text =
                          workerFeePurposeController.text == value ? '' : value,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _Label('Job description', required: true),
                ),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'hi', label: Text('हिंदी')),
                  ],
                  selected: {aiLanguage},
                  onSelectionChanged: (value) =>
                      setState(() => aiLanguage = value.first),
                ),
              ],
            ),
            _Input(
              hint:
                  'What the work is, what the karigar must know, anything they should bring…',
              controller: descriptionController,
              lines: 5,
              errorText: _fieldErrors['description'],
            ),
            TextButton.icon(
              onPressed: suggesting ? null : _suggestDescription,
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('Write with AI'),
            ),
          ],
        ),
      ),
    ],
  );

  String _daysText(Set<String> days) {
    const all = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    if (all.every(days.contains)) return 'Mon–Sat';
    return days.isEmpty ? 'Not selected' : days.join(', ');
  }

  String _experienceText() => switch (experienceLevel) {
    'freshers' => 'Freshers welcome',
    'experienced' =>
      '${experienceController.text.trim().isEmpty ? 1 : experienceController.text.trim()}+ years',
    _ => 'Anyone',
  };

  void _editStep(int step) => setState(() => _step = step);

  Widget _previewRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _previewSection({
    required String title,
    required int step,
    required List<Widget> rows,
  }) => _wizardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _editStep(step),
              icon: const Icon(LucideIcons.pencilLine, size: 17),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    ),
  );

  Widget _contactChoice({
    required String value,
    required String title,
    required String detail,
    bool? selected,
    ValueChanged<String>? onChanged,
  }) {
    final isSelected = selected ?? contact == value;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => setState(() {
          if (onChanged != null) {
            onChanged(value);
          } else {
            contact = value;
          }
        }),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brand50 : AppColors.card,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.line,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSelected ? LucideIcons.circleDot : LucideIcons.circle,
                color: isSelected ? AppColors.primary : AppColors.line,
                size: 25,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _matchPreview() {
    final craft = category ?? 'this craft';
    final localCity = city ?? 'your city';
    const people = [
      ('VY', 'Vimla Y.', '25 yrs exp', 'Sanganer'),
      ('RS', 'Rekha S.', '6 yrs exp', 'Malviya Nagar'),
      ('MA', 'Mohd. Arif', '9 yrs exp', 'Ramganj'),
      ('SD', 'Sunita D.', 'Fresher', 'Jhotwara'),
    ];
    return _wizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.userRoundCheck, color: AppColors.primary),
              SizedBox(width: 10),
              Text(
                'Karigars ready for this job',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              text: '12 ',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              children: [
                TextSpan(
                  text: 'karigars match, in $localCity.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...people.map(
            (person) => Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.brand100,
                    child: Text(
                      person.$1,
                      style: const TextStyle(
                        color: AppColors.brandDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.$2,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${person.$3} · $craft',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    person.$4,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'These karigars get your job in their feed and alerts once it is live.',
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _stepFourContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'This is how karigars will see your job. Tap Edit to change a part.',
          style: TextStyle(color: AppColors.muted, height: 1.35),
        ),
      ),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleController.text.trim().isEmpty
                  ? 'Your job title'
                  : titleController.text.trim(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            if (AppScope.maybeOf(
                  context,
                )?.profile.profile?.companyName.trim().isNotEmpty ==
                true)
              Text(
                AppScope.of(context).profile.profile!.companyName,
                style: const TextStyle(color: AppColors.muted),
              ),
            Text(
              [city, state].whereType<String>().join(', '),
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            BrandChip(category ?? 'Other'),
            const SizedBox(height: 14),
            Text(
              wageMinController.text.isEmpty
                  ? 'Pay not shown'
                  : '₹${wageMinController.text}${wageMaxController.text.isEmpty ? '' : ' – ₹${wageMaxController.text}'} a month',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              '${openingsController.text.isEmpty ? 1 : openingsController.text} opening${openingsController.text == '1' ? '' : 's'} · $shift shift',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _previewSection(
        title: 'Work & pay',
        step: 0,
        rows: [
          _previewRow('Craft', category ?? 'Not selected'),
          _previewRow(
            'Openings',
            openingsController.text.isEmpty ? '1' : openingsController.text,
          ),
          _previewRow(
            'Address',
            [city, state].whereType<String>().join(', ').isEmpty
                ? 'Not selected'
                : [city, state].whereType<String>().join(', '),
          ),
          _previewRow(
            'Pay',
            wageMinController.text.isEmpty
                ? 'Not shown'
                : '₹${wageMinController.text}${wageMaxController.text.isEmpty ? '' : ' – ₹${wageMaxController.text}'}',
          ),
        ],
      ),
      const SizedBox(height: 14),
      _previewSection(
        title: 'Karigar profile',
        step: 1,
        rows: [
          _previewRow('Experience', _experienceText()),
          _previewRow(
            'Who can apply',
            gender == 'male'
                ? 'Men'
                : gender == 'female'
                ? 'Women'
                : 'Men & women',
          ),
          _previewRow(
            'English',
            english[0].toUpperCase() + english.substring(1),
          ),
          _previewRow(
            'Karigars from',
            reach == 'nearby'
                ? 'Within $reachKm km'
                : 'Anywhere in ${reachCity ?? city ?? 'your city'}',
          ),
          _previewRow(
            'Other cities',
            relocationAllowed ? 'Yes, allow' : 'No, local only',
          ),
          if (selectedSkills.isNotEmpty)
            _previewRow('Skills', selectedSkills.join(', ')),
          if (selectedLanguages.isNotEmpty)
            _previewRow('Languages', selectedLanguages.join(', ')),
        ],
      ),
      const SizedBox(height: 14),
      _previewSection(
        title: 'Shift & interview',
        step: 2,
        rows: [
          _previewRow(
            'Shift',
            '$shift shift${shiftStartController.text.isEmpty ? '' : ' · ${shiftStartController.text} – ${shiftEndController.text}'}',
          ),
          _previewRow('Working days', _daysText(workDays)),
          _previewRow(
            'Work place',
            workMode == 'remote'
                ? 'Work from home'
                : workMode == 'both'
                ? 'Site & home'
                : 'At workplace / Site',
          ),
          _previewRow(
            'Interview',
            '${_daysText(interviewDays)}${interviewStartController.text.isEmpty ? '' : ' · ${interviewStartController.text} – ${interviewEndController.text}'}',
          ),
          _previewRow(
            'Interview at',
            _interviewAtWork ? 'The work address' : 'Another address',
          ),
          _previewRow(
            'Fee from karigar',
            requiresWorkerFee
                ? '₹${workerFeeAmountController.text.trim().isEmpty ? 'Not set' : workerFeeAmountController.text.trim()}'
                : 'No fee — free to join',
          ),
          if (descriptionController.text.trim().isNotEmpty)
            _previewRow('Description', descriptionController.text.trim()),
        ],
      ),
      const SizedBox(height: 14),
      _matchPreview(),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.phone, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'How should karigars reach you?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            _contactChoice(
              value: 'Apply in the app',
              title: 'Apply in the app',
              detail: 'Karigars apply here; you check them in Applicants.',
            ),
            _contactChoice(
              value: 'Call me directly',
              title: 'Call me directly',
              detail: 'Your number shows on the job. Karigars call you.',
            ),
            _contactChoice(
              value: 'Both',
              title: 'Both',
              detail: 'Karigars can apply in the app or call you.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.userRound, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Contact person',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Name (optional)'),
            _Input(
              hint: 'e.g. Ramesh Kumar',
              controller: contactNameController,
            ),
            const SizedBox(height: 12),
            _Label(
              contact == 'Apply in the app'
                  ? 'Designation (optional)'
                  : 'Designation',
              required: contact != 'Apply in the app',
            ),
            _Input(
              hint: 'e.g. Supervisor',
              controller: contactDesignationController,
              errorText: _fieldErrors['designation'],
            ),
            const SizedBox(height: 8),
            _singleChips(
              const ['Owner', 'Manager', 'Supervisor', 'HR'],
              contactDesignationController.text,
              (value) =>
                  setState(() => contactDesignationController.text = value),
            ),
            if (contact != 'Apply in the app') ...[
              const SizedBox(height: 12),
              const _Label('Number karigars will call', required: true),
              _Input(
                hint: '98765 43210',
                controller: contactPhoneController,
                number: true,
                maxLength: 10,
                errorText: _fieldErrors['phone'],
              ),
              const _Hint('This number shows on the job post.'),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.flame, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'When should they join?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            _contactChoice(
              value: 'immediate',
              title: 'Urgent — within 1–2 weeks',
              detail: 'Your job shows an “Urgent” tag.',
              selected: hiringUrgency == 'immediate',
              onChanged: (value) => hiringUrgency = value,
            ),
            _contactChoice(
              value: 'can_wait',
              title: 'No rush',
              detail: 'Finding the right karigar matters more.',
              selected: hiringUrgency == 'can_wait',
              onChanged: (value) => hiringUrgency = value,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _wizardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Job stays live till'),
            InkWell(
              onTap: _pickExpiryDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(LucideIcons.calendarDays, size: 19),
                ),
                child: Text(_expiryDateLabel),
              ),
            ),
            const _Hint('You can close it earlier from My Jobs.'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _AiHelpCard(
        shortlistEnabled: aiShortlistEnabled,
        callEnabled: aiCallEnabled,
        shortlistAvailable: aiShortlistAvailable,
        callAvailable: aiCallAvailable,
        creditsEnabled: aiCreditsEnabled,
        creditsCanEnable: aiCreditsCanEnable,
        creditsBalance: aiCreditsBalance,
        creditsMinForJob: aiCreditsMinForJob,
        onRecharge: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiCreditsScreen()),
        ),
        onShortlistChanged: aiShortlistAvailable
            ? (v) => setState(() => aiShortlistEnabled = v)
            : null,
        onCallChanged: aiCallAvailable && aiShortlistEnabled
            ? (v) => setState(() => aiCallEnabled = v)
            : null,
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.amberBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '⚠ Never ask a karigar for money that is not written on this job. Jobs that do are taken down.',
          style: TextStyle(color: AppColors.amber),
        ),
      ),
    ],
  );

  int _step = 0;
  DateTime? expiresAt = DateTime.now().add(const Duration(days: 14));
  String experienceLevel = 'any';
  String english = 'basic';
  String reach = 'city';
  int reachKm = 10;
  String? reachCity;
  String? reachState;
  bool relocationAllowed = false;
  bool _showAgeFilter = false;
  bool _showLanguagesFilter = false;
  bool _showAssetsFilter = false;
  bool _interviewAtWork = true;
  bool givesIncentive = false;
  bool _showSavedJobPrompt = true;
  String hiringUrgency = 'can_wait';
  final selectedLanguages = <String>{};
  final selectedAssets = <String>{};
  final workDays = <String>{'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
  final interviewDays = <String>{'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
  final selectedSkills = <String>{};
  final _suggestedSkills = <String>{};
  String liveStatus = 'active';
  bool get editingDraft =>
      widget.job?.isDraft == true || widget.job?.status == 'draft';
  bool get canDraft => widget.job == null || editingDraft;
  final selectedPerks = <String>{};
  String shift = 'Day';
  String? gender;
  List<Map<String, String>> genderOptions = const [
    {'value': 'male', 'label': 'Male'},
    {'value': 'female', 'label': 'Female'},
    {'value': 'both', 'label': 'Male & female'},
  ];
  Map<String, _ShiftDefault> shiftDefaults = const {
    'day': _ShiftDefault('09:00', '18:00'),
    'night': _ShiftDefault('21:00', '06:00'),
  };
  final rotationalTimings = <_ShiftTiming>[];
  int maxShiftTimings = 6;
  bool _shiftTimesTouched = false;
  final workHoursController = TextEditingController();
  String workHoursPeriod = 'day';
  bool addCoreHours = false;
  TimeOfDay? coreStartTime;
  TimeOfDay? coreEndTime;
  String contact = 'Both';
  String wageType = 'monthly';
  String workMode = 'on_site';
  String aiLanguage = 'en';
  String? category;
  String? state;
  String? city;
  String? contactPhoneError;
  List<String> formErrors = const [];
  final Map<String, String> _fieldErrors = {};
  Timer? _errorBannerTimer;
  bool loading = false;
  bool referenceLoading = true;
  bool suggesting = false;
  bool aiShortlistEnabled = true;
  bool aiCallEnabled = true;
  bool aiShortlistAvailable = true;
  bool aiCallAvailable = true;
  bool aiCreditsEnabled = true;
  bool aiCreditsCanEnable = true;
  int aiCreditsBalance = 0;
  int aiCreditsMinForJob = 10;
  bool _referenceLoaded = false;
  bool _categoryWasSuggested = false;
  bool _otherCategorySelected = false;
  bool _applyingTitleProfile = false;
  bool _skillsCameFromSuggestion = false;
  List<_JobProfile> jobProfiles = const [];
  List<String> categories = const [];
  List<String> skills = const [
    'Pipe Fitting',
    'Waterproofing',
    'Drainage',
    'Testing',
  ];
  Map<String, List<String>> categorySkills = const {};
  List<String> perks = const [
    'Food',
    'Accommodation',
    'Travel allowance',
    'Bonus',
    'Overtime pay',
    'Weekly off',
  ];
  LatLng? selectedLocation;
  List<String> states = const [];
  List<String> cities = const [];
  List<Map<String, String>> workModes = const [
    {'value': 'on_site', 'label': 'At workplace / Site'},
    {'value': 'remote', 'label': 'Work from home'},
    {'value': 'both', 'label': 'Both (Site & Home)'},
  ];
  Set<String> allowedWorkDays = const {};
  Set<String> allowedInterviewDays = const {};
  final titleController = TextEditingController();
  final openingsController = TextEditingController(text: '1');
  final experienceController = TextEditingController(text: '0');
  final experienceMaxController = TextEditingController();
  final wageMinController = TextEditingController();
  final wageMaxController = TextEditingController();
  final descriptionController = TextEditingController();
  final contactPhoneController = TextEditingController();
  final addressController = TextEditingController();
  final areaController = TextEditingController();
  final shiftStartController = TextEditingController();
  final shiftEndController = TextEditingController();
  TimeOfDay? shiftStartTime;
  TimeOfDay? shiftEndTime;
  final contactNameController = TextEditingController();
  final contactDesignationController = TextEditingController();
  final perkController = TextEditingController();
  final incentiveMaxController = TextEditingController();
  final incentiveTypeController = TextEditingController();
  final otherRequirementsController = TextEditingController();
  final ageMinController = TextEditingController();
  final ageMaxController = TextEditingController();
  final interviewStartController = TextEditingController(text: '11:00');
  final interviewEndController = TextEditingController(text: '16:00');
  final interviewAddressController = TextEditingController();
  final workerFeePurposeController = TextEditingController();
  final reachCityController = TextEditingController();
  final customSkillController = TextEditingController();
  final customLanguageController = TextEditingController();
  final customAssetController = TextEditingController();
  bool requiresWorkerFee = false;
  final workerFeeAmountController = TextEditingController();
  final _formScrollController = ScrollController();
  Timer? _titleDebounce;
  Timer? _reachCityDebounce;
  Timer? _locationDebounce;
  bool _reachCitySearching = false;
  List<Json> _reachCityMatches = const [];

  @override
  void initState() {
    super.initState();
    workHoursController.addListener(_refreshCoreHoursValidation);
    titleController.addListener(_titleChanged);

    final job = widget.job;
    if (job == null) return;
    if (job.latitude != null && job.longitude != null) {
      selectedLocation = LatLng(job.latitude!, job.longitude!);
    }
    titleController.text = job.title;
    descriptionController.text = job.description;
    openingsController.text = job.vacancies > 0 ? '${job.vacancies}' : '';
    experienceController.text = '${job.experienceMin}';
    experienceMaxController.text = job.experienceMax?.toString() ?? '';
    wageMinController.text = job.wageMin > 0 ? '${job.wageMin}' : '';
    wageMaxController.text = job.wageMax > 0 ? '${job.wageMax}' : '';
    contactPhoneController.text = job.contactPhone ?? '';
    addressController.text = job.address ?? '';
    shiftStartController.text = job.shiftStart ?? '';
    shiftEndController.text = job.shiftEnd ?? '';
    shiftStartTime = _parseTime(job.shiftStart);
    shiftEndTime = _parseTime(job.shiftEnd);
    gender = job.gender;
    rotationalTimings.addAll(
      job.shiftTimings.map(
        (timing) => _ShiftTiming(timing['start'] ?? '', timing['end'] ?? ''),
      ),
    );
    workHoursController.text = job.workHours == null
        ? ''
        : job.workHours!.toString().replaceFirst(RegExp(r'\.0$'), '');
    workHoursPeriod = job.workHoursPeriod ?? 'day';
    coreStartTime = _parseTime(job.coreStart);
    coreEndTime = _parseTime(job.coreEnd);
    addCoreHours = coreStartTime != null || coreEndTime != null;
    contactNameController.text = job.contactName ?? '';
    contactDesignationController.text = job.contactDesignation ?? '';
    category = job.category.isEmpty ? null : job.category;
    _otherCategorySelected = job.category.isEmpty;
    state = job.state.isEmpty ? null : job.state;
    city = job.city.isEmpty ? null : job.city;
    selectedSkills.addAll(job.skills);
    selectedPerks.addAll(job.perks);
    wageType = 'monthly';
    if (job.shift.isNotEmpty) {
      shift = '${job.shift[0].toUpperCase()}${job.shift.substring(1)}';
    }
    contact =
        {
          'both': 'Both',
          'call': 'Call me directly',
          'apply': 'Apply in the app',
        }[job.contactMode] ??
        'Apply in the app';
    workMode = job.workMode;
    liveStatus = job.status == 'closed' ? 'closed' : 'active';
    aiShortlistEnabled = job.aiShortlistEnabled;
    aiCallEnabled = job.aiCallEnabled;
    english = job.english == 'good' || job.english == 'fluent'
        ? job.english!
        : 'basic';
    reach = job.reach;
    reachKm = job.reachKm ?? 10;
    reachCity = job.reachCity;
    reachState = job.reachState;
    reachCityController.text = reachCity ?? '';
    relocationAllowed = job.relocationAllowed;
    selectedLanguages.addAll(job.languages);
    selectedAssets.addAll(job.assets);
    workDays
      ..clear()
      ..addAll(
        job.workDays.isEmpty
            ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            : job.workDays,
      );
    interviewDays
      ..clear()
      ..addAll(
        job.interviewDays.isEmpty
            ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            : job.interviewDays,
      );
    ageMinController.text = job.ageMin?.toString() ?? '';
    ageMaxController.text = job.ageMax?.toString() ?? '';
    givesIncentive = job.incentiveMax != null;
    incentiveMaxController.text = job.incentiveMax?.toString() ?? '';
    incentiveTypeController.text = job.incentiveType ?? '';
    otherRequirementsController.text = job.otherRequirements ?? '';
    interviewStartController.text = job.interviewStart ?? '11:00';
    interviewEndController.text = job.interviewEnd ?? '16:00';
    interviewAddressController.text = job.interviewAddress ?? '';
    workerFeePurposeController.text = job.workerFeePurpose ?? '';
    requiresWorkerFee = job.requiresWorkerFee;
    workerFeeAmountController.text = job.workerFeeAmount?.toString() ?? '';
    hiringUrgency = job.hiringUrgency;
  }

  void _titleChanged() {
    if (_fieldErrors.containsKey('title') &&
        titleController.text.trim().isNotEmpty) {
      setState(() => _fieldErrors.remove('title'));
    }
    if (_applyingTitleProfile) {
      _applyingTitleProfile = false;
      return;
    }
    _titleDebounce?.cancel();
    final title = titleController.text.trim();
    if (title.length < 2) return;
    _titleDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _suggestFromTitle(title),
    );
  }

  TimeOfDay? _parseTime(String? value) {
    final parts = (value ?? '').split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickTime({required bool start}) async {
    final initial = start ? shiftStartTime : shiftEndTime;
    final selected = await showTimePicker(
      context: context,
      initialTime:
          initial ??
          (start
              ? const TimeOfDay(hour: 9, minute: 0)
              : const TimeOfDay(hour: 17, minute: 0)),
    );
    if (selected == null || !mounted) return;
    final value =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (start) {
        shiftStartTime = selected;
        shiftStartController.text = value;
      } else {
        shiftEndTime = selected;
        shiftEndController.text = value;
      }
      _shiftTimesTouched = true;
    });
  }

  Future<TimeOfDay?> _chooseTime(TimeOfDay? initial) => showTimePicker(
    context: context,
    initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0),
  );

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _pickRotationalTime(int index, {required bool start}) async {
    final timing = rotationalTimings[index];
    final selected = await _chooseTime(
      _parseTime(start ? timing.start : timing.end),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        timing.start = _formatTime(selected);
      } else {
        timing.end = _formatTime(selected);
      }
    });
  }

  Future<void> _pickCoreTime({required bool start}) async {
    final selected = await _chooseTime(start ? coreStartTime : coreEndTime);
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        coreStartTime = selected;
      } else {
        coreEndTime = selected;
      }
    });
  }

  void _changeShift(String value) {
    final previous = shift.toLowerCase();
    final next = value.toLowerCase();
    setState(() {
      shift = value;
      if (next == 'rotational' && rotationalTimings.isEmpty) {
        rotationalTimings.add(_ShiftTiming('', ''));
      }
      if ((next == 'day' || next == 'night') &&
          (!_shiftTimesTouched || (previous != 'day' && previous != 'night'))) {
        final defaults = shiftDefaults[next];
        if (defaults != null) {
          shiftStartController.text = defaults.start;
          shiftEndController.text = defaults.end;
          shiftStartTime = _parseTime(defaults.start);
          shiftEndTime = _parseTime(defaults.end);
        }
      }
    });
  }

  void _refreshCoreHoursValidation() {
    if (mounted) setState(() {});
  }

  String? get _coreHoursError {
    if (!addCoreHours || coreStartTime == null || coreEndTime == null)
      return null;
    final hours = num.tryParse(workHoursController.text);
    if (hours == null || hours <= 0)
      return 'Enter the total working hours first.';
    final start = coreStartTime!.hour * 60 + coreStartTime!.minute;
    final end = coreEndTime!.hour * 60 + coreEndTime!.minute;
    final core = ((end - start + 1440) % 1440) / 60;
    final daily = workHoursPeriod == 'week' ? hours / 6 : hours;
    if (core == 0 || core > daily) {
      return 'Core hours (${core.toStringAsFixed(core % 1 == 0 ? 0 : 1)} hrs) can’t be more than the working hours in a day (${daily.toStringAsFixed(daily % 1 == 0 ? 0 : 1)} hrs).';
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_referenceLoaded) {
      _referenceLoaded = true;
      _loadReference();
    }
  }

  Future<void> _loadReference() async {
    try {
      final response = await AppScope.of(context).api.reference();
      if (!mounted) return;
      setState(() {
        categories = _names(response['job_categories']);
        final apiSkills = _names(response['skills']);
        final rawCategorySkills =
            response['category_skills'] as Map? ?? const {};
        categorySkills = rawCategorySkills.map(
          (key, value) => MapEntry('$key', _names(value)),
        );
        final referenceDefaults = _shiftDefaults(response['shift_defaults']);
        if (referenceDefaults.isNotEmpty) shiftDefaults = referenceDefaults;
        if (widget.job == null &&
            shiftStartTime == null &&
            shiftEndTime == null) {
          final defaults = shiftDefaults['day'];
          if (defaults != null) {
            shiftStartController.text = defaults.start;
            shiftEndController.text = defaults.end;
            shiftStartTime = _parseTime(defaults.start);
            shiftEndTime = _parseTime(defaults.end);
          }
        }
        final apiPerks = _names(response['perks']);
        states = _names(response['states']);
        if (city != null) cities = [city!];
        // Skills only make sense after the employer chooses a category. Do not
        // show the global API list (for example knitting for a logistics job).
        skills = category == null
            ? <String>[]
            : {
                ...(categorySkills[category] ?? apiSkills),
                ...selectedSkills,
              }.toList();
        perks = {...apiPerks, ...selectedPerks}.toList();
      });
      if (state != null) unawaited(_loadCities(state!, keepSelectedCity: true));
      try {
        final options = await AppScope.of(context).api.jobFormOptions();
        final profiles = (options['job_profiles'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => _JobProfile(
                title: '${item['title'] ?? ''}',
                category: '${item['category'] ?? ''}',
              ),
            )
            .where((profile) => profile.title.isNotEmpty)
            .toList();
        final ai = options['ai'];
        if (mounted) {
          final parsedWorkModes = _modeOptions(options['work_modes']);
          if (parsedWorkModes.isNotEmpty) workModes = parsedWorkModes;
          final parsedGenders = _modeOptions(options['genders']);
          final optionWorkDays = _optionValues(options['work_days']);
          final optionInterviewDays = _optionValues(
            options['interview_days'] ?? options['work_days'],
          );
          final optionDefaults = _shiftDefaults(options['shift_defaults']);
          final maxTimings = (options['max_shift_timings'] as num?)?.toInt();
          setState(() {
            if (parsedGenders.isNotEmpty) genderOptions = parsedGenders;
            if (optionWorkDays.isNotEmpty) allowedWorkDays = optionWorkDays;
            if (optionInterviewDays.isNotEmpty) {
              allowedInterviewDays = optionInterviewDays;
            }
            if (optionDefaults.isNotEmpty) shiftDefaults = optionDefaults;
            if (maxTimings != null && maxTimings > 0) {
              maxShiftTimings = maxTimings;
            }
            jobProfiles = profiles;
          });
          if (ai is! Map) return;
          final credits = ai['credits'];
          setState(() {
            aiShortlistAvailable = ai['shortlist_available'] != false;
            aiCallAvailable = ai['call_available'] != false;
            if (credits is Map) {
              aiCreditsEnabled = credits['enabled'] != false;
              aiCreditsCanEnable = credits['can_enable'] != false;
              aiCreditsBalance = (credits['balance'] as num?)?.toInt() ?? 0;
              aiCreditsMinForJob =
                  (credits['min_for_job'] as num?)?.toInt() ?? 10;
              if (widget.job == null &&
                  aiCreditsEnabled &&
                  !aiCreditsCanEnable) {
                aiCallEnabled = false;
              } else if (widget.job == null && aiCreditsCanEnable) {
                aiCallEnabled = true;
              }
            }
          });
        }
      } catch (_) {
        // Keep the switches available when older servers do not expose options.
      }
    } catch (_) {
      // Bundled options keep this form usable while reference data is offline.
    } finally {
      if (mounted) setState(() => referenceLoading = false);
    }
  }

  Future<void> _suggestFromTitle(String title) async {
    try {
      final suggestion = await AppScope.of(
        context,
      ).api.suggestJobCategory(title);
      if (!mounted || title != titleController.text.trim()) return;
      if (suggestion == null) {
        if (_categoryWasSuggested) {
          setState(() {
            category = null;
            _categoryWasSuggested = false;
            _otherCategorySelected = false;
            if (_skillsCameFromSuggestion) {
              selectedSkills.removeAll(_suggestedSkills);
              _suggestedSkills.clear();
              _skillsCameFromSuggestion = false;
            }
          });
          unawaited(_chooseCategory());
        }
        return;
      }
      final suggestedCategory = '${suggestion['category'] ?? ''}'.trim();
      final suggestedSkills = _names(suggestion['skills']).take(3).toSet();
      setState(() {
        if (suggestedCategory.isNotEmpty &&
            (category == null || _categoryWasSuggested)) {
          category = suggestedCategory;
          _categoryWasSuggested = true;
          _otherCategorySelected = false;
          skills = {
            ...(categorySkills[suggestedCategory] ?? skills),
            ...selectedSkills,
          }.toList();
        }
        if (suggestedSkills.isNotEmpty &&
            (selectedSkills.isEmpty || _skillsCameFromSuggestion)) {
          selectedSkills
            ..clear()
            ..addAll(suggestedSkills);
          _suggestedSkills
            ..clear()
            ..addAll(suggestedSkills);
          _skillsCameFromSuggestion = true;
        }
      });
    } catch (_) {
      // Suggestions are optional; posting stays available when the endpoint is offline.
    }
  }

  void _selectJobProfile(_JobProfile picked) {
    _titleDebounce?.cancel();
    setState(() {
      _applyingTitleProfile = true;
      titleController.text = picked.title;
      category = picked.category;
      _categoryWasSuggested = false;
      _otherCategorySelected = false;
      skills = {
        ...(categorySkills[picked.category] ?? skills),
        ...selectedSkills,
      }.toList();
    });
  }

  void _addOwnTitle() {
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    _titleDebounce?.cancel();
    unawaited(_suggestFromTitle(title));
  }

  void _searchReachCity(String text) {
    _reachCityDebounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _reachCitySearching = false;
        _reachCityMatches = const [];
      });
      return;
    }
    _reachCityDebounce = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted) return;
      setState(() => _reachCitySearching = true);
      try {
        final matches = await AppScope.of(context).api.searchCities(text);
        if (!mounted || text != reachCityController.text) return;
        setState(() => _reachCityMatches = matches.take(8).toList());
      } catch (_) {
        if (mounted) setState(() => _reachCityMatches = const []);
      } finally {
        if (mounted && text == reachCityController.text) {
          setState(() => _reachCitySearching = false);
        }
      }
    });
  }

  void _showReachCitySuggestions() {
    if (_reachCitySearching || _reachCityMatches.isNotEmpty) return;
    final query = reachCityController.text.trim();
    if (query.isNotEmpty) {
      _searchReachCity(query);
      return;
    }
    setState(() {
      _reachCityMatches = cities
          .take(8)
          .map<Json>((name) => {'city': name, 'state': state ?? ''})
          .toList();
    });
  }

  void _pickReachCity(Json match) {
    setState(() {
      reachCity = '${match['city']}';
      reachState = '${match['state']}';
      reachCityController.text = reachCity!;
      _reachCityMatches = const [];
    });
  }

  Future<void> _chooseCategory() async {
    final result = await showSearchableOptionSheet(
      context,
      title: 'Select category',
      values: [...categories, 'Other (not in the list)'],
    );
    if (result == null || !mounted) return;
    setState(() {
      _otherCategorySelected = result == 'Other (not in the list)';
      _fieldErrors.remove('category');
      category = _otherCategorySelected ? null : result;
      _categoryWasSuggested = false;
      if (!_otherCategorySelected) {
        skills = {
          ...(categorySkills[result] ?? skills),
          ...selectedSkills,
        }.toList();
      }
    });
  }

  List<String> _names(dynamic value) => (value as List? ?? const [])
      .map((item) {
        if (item is Map) return '${item['name'] ?? item['label'] ?? ''}';
        return '$item';
      })
      .where((item) => item.isNotEmpty)
      .toList();

  List<Map<String, String>> _modeOptions(dynamic value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => {
              'value': '${item['value'] ?? ''}',
              'label': '${item['label'] ?? item['value'] ?? ''}',
            },
          )
          .where((item) => item['value']!.isNotEmpty)
          .toList();

  Set<String> _optionValues(dynamic value) => (value as List? ?? const [])
      .map((item) {
        if (item is Map)
          return '${item['value'] ?? item['key'] ?? item['id'] ?? ''}';
        return '$item';
      })
      .where((item) => item.isNotEmpty)
      .toSet();

  Map<String, _ShiftDefault> _shiftDefaults(dynamic value) {
    if (value is! Map) return const {};
    final defaults = <String, _ShiftDefault>{};
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      final item = entry.value as Map;
      final start = '${item['start'] ?? ''}';
      final end = '${item['end'] ?? ''}';
      if (start.isNotEmpty && end.isNotEmpty) {
        defaults['${entry.key}'.toLowerCase()] = _ShiftDefault(start, end);
      }
    }
    return defaults;
  }

  Future<void> _loadCities(
    String value, {
    bool keepSelectedCity = false,
    bool keepSelectedLocation = false,
  }) async {
    setState(() {
      state = value;
      if (!keepSelectedCity) city = null;
      if (!keepSelectedLocation) selectedLocation = null;
      cities = const [];
    });
    try {
      final result = await AppScope.of(context).api.cities(value);
      if (mounted && state == value) {
        setState(() => cities = {...result, ?city}.toList());
      }
    } catch (_) {
      _message('Could not load cities.');
    }
  }

  Future<void> _pinFromEnteredLocation() async {
    final query = [
      addressController.text.trim(),
      if (areaController.text.trim() != addressController.text.trim())
        areaController.text.trim(),
      ?city,
      ?state,
      'India',
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
    if (query.isEmpty) return;
    try {
      final places = await locationFromAddress(query);
      if (!mounted || places.isEmpty) return;
      setState(
        () => selectedLocation = LatLng(
          places.first.latitude,
          places.first.longitude,
        ),
      );
    } catch (_) {
      // Leave manual entry usable when device geocoding is unavailable.
    }
  }

  void _schedulePinFromAddress(String _) {
    _locationDebounce?.cancel();
    if (addressController.text.trim().isEmpty && city == null) return;
    _locationDebounce = Timer(
      const Duration(milliseconds: 650),
      () => unawaited(_pinFromEnteredLocation()),
    );
  }

  Future<void> _syncLocationFromMap(LatLng point) async {
    setState(() => selectedLocation = point);
    try {
      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (!mounted || places.isEmpty) return;
      final place = places.first;
      final detectedState = place.administrativeArea?.trim();
      final detectedCity =
          (place.locality?.trim().isNotEmpty == true
                  ? place.locality
                  : place.subAdministrativeArea)
              ?.trim();
      if (detectedState != null &&
          detectedState.isNotEmpty &&
          state != detectedState) {
        await _loadCities(detectedState, keepSelectedLocation: true);
      }
      if (!mounted) return;
      setState(() {
        if (detectedCity != null && detectedCity.isNotEmpty) {
          city = detectedCity;
        }
        final area = place.subLocality?.trim() ?? place.thoroughfare?.trim();
        if (area != null && area.isNotEmpty) {
          areaController.text = area;
          addressController.text = area;
        }
      });
    } catch (_) {
      // Keep the selected coordinates when reverse geocoding is unavailable.
    }
  }

  Future<void> _submit(String status) async {
    if (loading) return;
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final vacancies = int.tryParse(openingsController.text);
    final experience = int.tryParse(experienceController.text);
    final experienceMax = int.tryParse(experienceMaxController.text);
    final wageMin = num.tryParse(wageMinController.text);
    final wageMax = num.tryParse(wageMaxController.text);
    final workHours = num.tryParse(workHoursController.text);
    final shiftValue = shift.toLowerCase();
    final contactMode = {
      'Both': 'both',
      'Call me directly': 'call',
      'Apply in the app': 'apply',
    }[contact]!;
    final draft = status == 'draft';
    if (!draft) {
      for (var step = 0; step < 4; step++) {
        final errors = _stepValidationErrors(step);
        if (errors.isNotEmpty) {
          setState(() => _step = step);
          _showValidationErrors(errors);
          return;
        }
      }
    }
    if (title.isEmpty) {
      _message('Enter a job title.');
      return;
    }
    if (!draft && category == null && !_otherCategorySelected) {
      _message('Pick a category, or Other if none fits.');
      return;
    }
    if (!draft &&
        (description.isEmpty ||
            state == null ||
            city == null ||
            vacancies == null ||
            vacancies < 1)) {
      _message('Complete all required job details.');
      return;
    }
    if (!draft && wageMax != null && wageMin != null && wageMax < wageMin) {
      _message('Maximum wage cannot be lower than minimum wage.');
      return;
    }
    if (!draft &&
        givesIncentive &&
        (double.tryParse(incentiveMaxController.text.trim()) ?? 0) <= 0) {
      _message('Enter the monthly bonus or incentive amount.');
      return;
    }
    if (!draft && reach == 'nearby' && (reachKm < 1 || reachKm > 50)) {
      _message('Choose a range between 1 and 50 km.');
      return;
    }
    if (!draft &&
        reach == 'city' &&
        (reachCity == null || reachState == null)) {
      _message('Pick the city the karigars should come from.');
      return;
    }
    if (!draft &&
        requiresWorkerFee &&
        (num.tryParse(workerFeeAmountController.text.trim()) ?? 0) <= 0) {
      _message('Enter the fee amount.');
      return;
    }
    final ageMin = int.tryParse(ageMinController.text.trim());
    final ageMax = int.tryParse(ageMaxController.text.trim());
    if (!draft &&
        ((ageMin != null && ageMin < 18) ||
            (ageMax != null && ageMax < 18) ||
            (ageMin != null && ageMax != null && ageMax < ageMin))) {
      _message(
        'Age must be 18–70 and the maximum cannot be lower than minimum.',
      );
      return;
    }
    if (!draft &&
        experience != null &&
        experienceMax != null &&
        experienceMax < experience) {
      _message('Maximum experience cannot be lower than minimum experience.');
      return;
    }
    if (!draft &&
        (shiftValue == 'day' || shiftValue == 'night') &&
        ((shiftStartController.text.trim().isEmpty) !=
            (shiftEndController.text.trim().isEmpty))) {
      _message('Enter both shift start and end times, or leave both blank.');
      return;
    }
    if (!draft && shiftValue == 'rotational') {
      for (var index = 0; index < rotationalTimings.length; index++) {
        final timing = rotationalTimings[index];
        if (timing.start.isEmpty ||
            timing.end.isEmpty ||
            timing.start == timing.end) {
          _message('Shift ${index + 1} needs different start and end times.');
          return;
        }
      }
    }
    if (!draft && shiftValue == 'flexible') {
      final maximum = workHoursPeriod == 'week' ? 168 : 24;
      if (workHours == null || workHours <= 0 || workHours > maximum) {
        _message(
          'Enter working hours between 1 and $maximum per $workHoursPeriod.',
        );
        return;
      }
      if (addCoreHours && (coreStartTime == null || coreEndTime == null)) {
        _message('Enter both core working hours.');
        return;
      }
      if (addCoreHours) {
        if (_coreHoursError != null) {
          _message(_coreHoursError!);
          return;
        }
      }
    }
    if (!draft &&
        contactMode != 'apply' &&
        !RegExp(r'^[6-9]\d{9}$').hasMatch(contactPhoneController.text.trim())) {
      _message('Enter a valid 10-digit contact number.');
      return;
    }
    if (!draft &&
        contactMode != 'apply' &&
        contactDesignationController.text.trim().isEmpty) {
      _message('Enter the designation of the person who picks up calls.');
      return;
    }
    final values = <String, dynamic>{
      'title': title,
      if (description.isNotEmpty) 'description': description,
      'category': ?category,
      'gender': ?gender,
      'english': english,
      'reach': reach,
      if (reach == 'nearby') 'reach_km': reachKm,
      if (reach == 'city') 'reach_city': reachCity,
      if (reach == 'city') 'reach_state': reachState,
      'relocation_allowed': relocationAllowed,
      'languages': selectedLanguages.toList(),
      'assets': selectedAssets.map(_assetBodyValue).toList(),
      if (workDays.any(allowedWorkDays.contains))
        'work_days': workDays.where(allowedWorkDays.contains).toList(),
      if (interviewDays.any(allowedInterviewDays.contains))
        'interview_days': interviewDays
            .where(allowedInterviewDays.contains)
            .toList(),
      'hiring_urgency': hiringUrgency,
      if (expiresAt != null)
        'expires_at':
            '${expiresAt!.year.toString().padLeft(4, '0')}-${expiresAt!.month.toString().padLeft(2, '0')}-${expiresAt!.day.toString().padLeft(2, '0')}',
      if (experienceLevel == 'freshers') 'experience_min': 0,
      if (experienceLevel == 'freshers') 'experience_max': 0,
      if (ageMinController.text.trim().isNotEmpty)
        'age_min': int.tryParse(ageMinController.text.trim()),
      if (ageMaxController.text.trim().isNotEmpty)
        'age_max': int.tryParse(ageMaxController.text.trim()),
      if (givesIncentive)
        'incentive_max': double.tryParse(incentiveMaxController.text.trim()),
      if (givesIncentive && incentiveTypeController.text.trim().isNotEmpty)
        'incentive_type': incentiveTypeController.text.trim(),
      if (otherRequirementsController.text.trim().isNotEmpty)
        'other_requirements': otherRequirementsController.text.trim(),
      if (!draft || selectedSkills.isNotEmpty)
        'skills': selectedSkills.toList(),
      if (wageMin != null && wageMin >= 0) 'wage_min': wageMin,
      if (wageMax != null && wageMax >= (wageMin ?? 0)) 'wage_max': wageMax,
      if (!draft || wageMin != null || wageMax != null) 'wage_type': wageType,
      'city': ?city,
      'state': ?state,
      if (areaController.text.trim().isNotEmpty ||
          addressController.text.trim().isNotEmpty)
        'address': [
          if (areaController.text.trim().isNotEmpty)
            'Area: ${areaController.text.trim()}',
          if (addressController.text.trim().isNotEmpty)
            addressController.text.trim(),
        ].join(', '),
      if (selectedLocation != null) 'latitude': selectedLocation!.latitude,
      if (selectedLocation != null) 'longitude': selectedLocation!.longitude,
      if (!draft && vacancies != null && vacancies > 0) 'vacancies': vacancies,
      if (!draft || (experience != null && experience > 0))
        'experience_min': experience != null && experience >= 0
            ? experience
            : 0,
      if (experienceMax != null && experienceMax >= 0)
        'experience_max': experienceMax,
      if (!draft) 'shift': shiftValue,
      if ((shiftValue == 'day' || shiftValue == 'night') &&
          shiftStartController.text.trim().isNotEmpty)
        'shift_start': shiftStartController.text.trim(),
      if ((shiftValue == 'day' || shiftValue == 'night') &&
          shiftEndController.text.trim().isNotEmpty)
        'shift_end': shiftEndController.text.trim(),
      if (shiftValue == 'rotational')
        'shift_timings': rotationalTimings
            .where((timing) => timing.start.isNotEmpty || timing.end.isNotEmpty)
            .map((timing) => {'start': timing.start, 'end': timing.end})
            .toList(),
      if (shiftValue == 'flexible' && workHours != null)
        'work_hours': workHours,
      if (shiftValue == 'flexible' && workHours != null)
        'work_hours_period': workHoursPeriod,
      if (shiftValue == 'flexible' && addCoreHours && coreStartTime != null)
        'core_start': _formatTime(coreStartTime!),
      if (shiftValue == 'flexible' && addCoreHours && coreEndTime != null)
        'core_end': _formatTime(coreEndTime!),
      if (!draft || selectedPerks.isNotEmpty) 'perks': selectedPerks.toList(),
      'contact_mode':
          draft &&
              !RegExp(
                r'^[6-9]\d{9}$',
              ).hasMatch(contactPhoneController.text.trim())
          ? 'apply'
          : contactMode,
      'work_mode': workMode,
      if (interviewStartController.text.trim().isNotEmpty)
        'interview_start': interviewStartController.text.trim(),
      if (interviewEndController.text.trim().isNotEmpty)
        'interview_end': interviewEndController.text.trim(),
      if (workMode != 'remote')
        'interview_address': _interviewAtWork
            ? null
            : interviewAddressController.text.trim().isEmpty
            ? null
            : interviewAddressController.text.trim(),
      if (workerFeePurposeController.text.trim().isNotEmpty)
        'worker_fee_purpose': workerFeePurposeController.text.trim(),
      if (contactMode != 'apply' &&
          RegExp(r'^[6-9]\d{9}$').hasMatch(contactPhoneController.text.trim()))
        'contact_phone': contactPhoneController.text.trim(),
      if (!draft && contactMode != 'apply')
        'contact_name': contactNameController.text.trim(),
      if (!draft && contactMode != 'apply')
        'contact_designation': contactDesignationController.text.trim(),
      'requires_worker_fee': requiresWorkerFee,
      'worker_fee_amount': requiresWorkerFee
          ? num.tryParse(workerFeeAmountController.text.trim())
          : null,
      'ai_shortlist_enabled': aiShortlistEnabled,
      'ai_call_enabled': aiCallEnabled,
      'status': status,
    };
    setState(() => loading = true);
    try {
      final response = await AppScope.of(
        context,
      ).api.saveJob(values, id: widget.job?.id);
      if (!mounted) return;
      if (response['code'] == 'job_checking') {
        await _showJobCheckingDialog(
          response['message']?.toString() ??
              'We are running a quick safety check. Your job will go live in a minute or two.',
        );
        if (mounted) Navigator.pop(context, JobPostResult.checking);
        return;
      }
      if (response['code'] == 'job_under_review') {
        final rawJob = response['job'];
        final moderation = rawJob is Map && rawJob['moderation'] is Map
            ? Map<String, dynamic>.from(rawJob['moderation'] as Map)
            : const <String, dynamic>{};
        final reasons = (moderation['reasons'] as List? ?? const [])
            .map((item) => '$item')
            .where((item) => item.isNotEmpty)
            .join('\n• ');
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(LucideIcons.shieldAlert, color: AppColors.amber),
            title: const Text('Job under review'),
            content: Text(
              '${response['message'] ?? 'Your job needs a quick review before it goes live.'}'
              '${reasons.isEmpty ? '' : '\n\nReason:\n• $reasons'}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Okay'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, true);
        return;
      }
      _message(
        '${response['message'] ?? (draft ? 'Draft saved.' : 'Job posted.')}',
      );
      Navigator.pop(context, true);
    } on ApiException catch (exception) {
      if (!mounted) return;
      if (!draft &&
          canDraft &&
          exception.statusCode == 422 &&
          (exception.code == 'no_plan' ||
              exception.code == 'subscription_required' ||
              exception.code == 'job_limit_reached' ||
              exception.message.contains('job posts') ||
              exception.message.contains('Subscribe to a plan'))) {
        final action = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 640),
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    exception.code == 'subscription_required'
                        ? 'Renew your plan'
                        : 'Choose a plan to continue',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(exception.message),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'draft'),
                    child: const Text('Save as draft'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, 'plans'),
                    child: Text(
                      exception.code == 'subscription_required'
                          ? 'Renew plan'
                          : 'See plans',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (!mounted) return;
        setState(() => loading = false);
        if (action == 'draft') await _submit('draft');
        if (action == 'plans' && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlansScreen()),
          );
        }
      } else if (exception.code == 'ai_credits_required') {
        final recharge = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('AI call credits needed'),
            content: Text(exception.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Recharge credits'),
              ),
            ],
          ),
        );
        if (recharge == true && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiCreditsScreen()),
          );
        }
      } else if (exception.code == 'verification_required') {
        final action = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Business verification required'),
            content: Text(exception.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Verify business'),
              ),
            ],
          ),
        );
        if (action == true && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const KycScreen()),
          );
        }
      } else {
        final errors = exception.errors?.values
            .expand((value) => value is List ? value : [value])
            .map((value) => '$value')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
        setState(
          () => formErrors = errors?.isNotEmpty == true
              ? errors!
              : [exception.message],
        );
        if (_formScrollController.hasClients) {
          await _formScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (exception) {
      if (mounted) _message('$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showJobCheckingDialog(String message) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                // Keep both dimensions fixed so the spinner cannot be stretched
                // by a dialog layout constraint on wider screens.
                child: SizedBox.square(
                  dimension: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Checking your job',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('View my jobs'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _suggestDescription() async {
    final title = titleController.text.trim();
    if (title.length < 3) {
      _message('Enter a job title first.');
      return;
    }
    setState(() => suggesting = true);
    try {
      final suggestions = await AppScope.of(context).api.suggestJobDescription(
        title: title,
        category: category,
        city: city,
        state: state,
        skills: selectedSkills.toList(),
        language: aiLanguage,
      );
      if (!mounted) return;
      if (suggestions.isEmpty) {
        _message('No description suggestion is available right now.');
        return;
      }
      final selected = suggestions.length == 1
          ? suggestions.first
          : await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (context) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    const Text(
                      'Choose a description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...suggestions.map(
                      (suggestion) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(suggestion),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () => Navigator.pop(context, suggestion),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
      if (selected != null) {
        descriptionController.text = selected;
      }
    } catch (exception) {
      if (mounted) _message('$exception');
    } finally {
      if (mounted) setState(() => suggesting = false);
    }
  }

  void _message(String text, {String? field}) {
    if (!mounted) return;
    _errorBannerTimer?.cancel();
    setState(() {
      formErrors = [text];
      if (field != null) _fieldErrors[field] = text;
    });
    _errorBannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => formErrors = const []);
    });
    if (_formScrollController.hasClients) {
      unawaited(
        _formScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _goNext() {
    final errors = _stepValidationErrors(_step);
    if (errors.isNotEmpty) {
      _showValidationErrors(errors);
      return;
    }
    _errorBannerTimer?.cancel();
    setState(() {
      formErrors = const [];
      _fieldErrors.clear();
      _step++;
    });
  }

  void _showValidationErrors(Map<String, String> errors) {
    if (!mounted) return;
    _errorBannerTimer?.cancel();
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
      formErrors = const ['Fill in the fields marked in red to go on.'];
    });
    _errorBannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => formErrors = const []);
    });
    if (_formScrollController.hasClients) {
      unawaited(
        _formScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  Map<String, String> _stepValidationErrors(int step) {
    final errors = <String, String>{};
    final wageMin = num.tryParse(wageMinController.text.trim());
    final wageMax = num.tryParse(wageMaxController.text.trim());
    if (step == 0) {
      if (titleController.text.trim().isEmpty) {
        errors['title'] = 'Enter the job title.';
      }
      if (category == null && !_otherCategorySelected) {
        errors['category'] = 'Pick the craft, or “Other”.';
      }
      if ((int.tryParse(openingsController.text) ?? 0) < 1) {
        errors['openings'] = 'Enter how many karigars you need.';
      }
      if (state == null) errors['state'] = 'Pick the state.';
      if (city == null) errors['city'] = 'Pick the city.';
      if (wageMin != null && wageMax != null && wageMax < wageMin) {
        errors['wage'] = '“To” can’t be less than “From”.';
      }
      if (givesIncentive &&
          (num.tryParse(incentiveMaxController.text.trim()) ?? 0) <= 0) {
        errors['incentive'] = 'Enter the monthly bonus or incentive amount.';
      }
    }
    if (step == 1) {
      final min = int.tryParse(experienceController.text.trim());
      final max = int.tryParse(experienceMaxController.text.trim());
      if (experienceLevel == 'experienced' && (min == null || min < 1)) {
        errors['experienceMin'] = 'Enter at least 1 year.';
      }
      if (min != null && max != null && max < min) {
        errors['experienceMax'] = 'Max years can’t be less than min years.';
      }
      if (reach == 'nearby' && (reachKm < 1 || reachKm > 50)) {
        errors['reachCity'] = 'Choose a range between 1 and 50 km.';
      }
      if (reach == 'city' && (reachCity == null || reachState == null)) {
        errors['reachCity'] = 'Pick the city the karigars should come from.';
      }
      final ageMin = int.tryParse(ageMinController.text.trim());
      final ageMax = int.tryParse(ageMaxController.text.trim());
      if (ageMin != null && ageMin < 18) {
        errors['ageMin'] = 'Min age can’t be under 18.';
      }
      if (ageMax != null && ageMax < 18) {
        errors['ageMax'] = 'Max age can’t be under 18.';
      }
      if (ageMin != null && ageMax != null && ageMax < ageMin) {
        errors['ageMax'] = 'Max age can’t be less than min age.';
      }
    }
    if (step == 2) {
      if (_coreHoursError != null) errors['interviewTime'] = _coreHoursError!;
      final hasStart = interviewStartController.text.trim().isNotEmpty;
      final hasEnd = interviewEndController.text.trim().isNotEmpty;
      if (hasStart != hasEnd) {
        errors['interviewTime'] = 'Give both interview times, or neither.';
      }
      if (requiresWorkerFee &&
          (num.tryParse(workerFeeAmountController.text.trim()) ?? 0) <= 0) {
        errors['fee'] = 'Enter the fee amount.';
      }
      if (descriptionController.text.trim().isEmpty) {
        errors['description'] =
            'Write a short description, or tap “Write with AI”.';
      }
    }
    if (step == 3 && contact != 'Apply in the app') {
      if (contactDesignationController.text.trim().isEmpty) {
        errors['designation'] = 'Enter the contact person’s designation.';
      }
      if (!RegExp(
        r'^[6-9]\d{9}$',
      ).hasMatch(contactPhoneController.text.trim())) {
        errors['phone'] = 'Enter a valid 10-digit mobile number.';
      }
    }
    return errors;
  }

  Widget _flowPanel() {
    const labels = [
      'Work & pay',
      'Karigar profile',
      'Shift & interview',
      'Preview & publish',
    ];
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step ${_step + 1} of 4',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _step = index),
                    child: Container(
                      margin: EdgeInsets.only(right: index == 3 ? 0 : 5),
                      height: 5,
                      decoration: BoxDecoration(
                        color: index <= _step
                            ? AppColors.primary
                            : AppColors.line,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              labels[_step],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _step == 0
                  ? 'Start with the role, location and pay.'
                  : _step == 1
                  ? 'Set the requirements that matter for this role.'
                  : _step == 2
                  ? 'Give clear work and interview details.'
                  : 'Check the job before it goes live.',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (_step == 0) ...[
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Bonus / incentive on top',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Per-piece rate, overtime, festival bonus…',
                ),
                value: givesIncentive,
                onChanged: (value) => setState(() => givesIncentive = value),
              ),
              if (givesIncentive) ...[
                const SizedBox(height: 8),
                _Input(
                  hint: 'Up to ₹ a month',
                  prefix: '₹',
                  controller: incentiveMaxController,
                  number: true,
                ),
                const SizedBox(height: 8),
                _Input(
                  hint: 'For, e.g. Per-piece rate',
                  controller: incentiveTypeController,
                ),
              ],
              const SizedBox(height: 8),
              _Input(
                hint: 'Anything else you need? (optional)',
                controller: otherRequirementsController,
                lines: 2,
              ),
            ] else if (_step == 1) ...[
              const SizedBox(height: 14),
              const _Label('Experience'),
              _singleChips(
                ['any', 'freshers', 'experienced'],
                experienceLevel,
                (value) => setState(() => experienceLevel = value),
              ),
              const SizedBox(height: 12),
              const _Label('English'),
              _singleChips(
                ['basic', 'good', 'fluent'],
                english,
                (value) => setState(() => english = value),
              ),
              const SizedBox(height: 12),
              const _Label('Get karigars from'),
              _singleChips(
                ['nearby', 'city'],
                reach,
                (value) => setState(() => reach = value),
              ),
              if (reach == 'nearby') ...[
                Row(
                  children: [
                    const Text('Range'),
                    const Spacer(),
                    Text('within $reachKm km'),
                  ],
                ),
                Slider(
                  value: reachKm.toDouble(),
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '$reachKm km',
                  onChanged: (v) => setState(() => reachKm = v.round()),
                ),
              ] else ...[
                const SizedBox(height: 8),
                _Input(
                  hint: 'Type a city name',
                  controller: reachCityController,
                  onChanged: _searchReachCity,
                ),
                if (_reachCitySearching)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Searching…'),
                  ),
                ..._reachCityMatches.map(
                  (match) => ListTile(
                    dense: true,
                    title: Text('${match['city']}'),
                    trailing: Text(
                      '${match['state']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    onTap: () => setState(() {
                      reachCity = '${match['city']}';
                      reachState = '${match['state']}';
                      reachCityController.text = reachCity!;
                      _reachCityMatches = const [];
                    }),
                  ),
                ),
                if (city != null)
                  TextButton(
                    onPressed: () => setState(() {
                      reachCity = city;
                      reachState = state;
                      reachCityController.text = city!;
                    }),
                    child: Text('Same as the job: $city'),
                  ),
              ],
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow karigars moving from another city'),
                value: relocationAllowed,
                onChanged: (value) => setState(() => relocationAllowed = value),
              ),
              const _Label('More requirements: age (optional)'),
              Row(
                children: [
                  Expanded(
                    child: _Input(
                      hint: 'Min 18',
                      controller: ageMinController,
                      number: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Input(
                      hint: 'Max 70',
                      controller: ageMaxController,
                      number: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _Label('Languages (optional)'),
              _chips(
                ['Hindi', 'English', 'Marathi', 'Bengali', 'Tamil'],
                selectedLanguages,
                multi: true,
              ),
              const SizedBox(height: 12),
              const _Label('They must have (optional)'),
              _chips(
                [
                  'Aadhaar card',
                  'PAN card',
                  'Bank account',
                  'Smartphone',
                  'Bike',
                  'Driving licence',
                  'Own tools',
                ],
                selectedAssets,
                multi: true,
              ),
            ] else if (_step == 2) ...[
              const SizedBox(height: 14),
              const _Label('Working days'),
              _dayChips(workDays),
              const SizedBox(height: 12),
              const _Label('Interview days'),
              _dayChips(interviewDays),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Input(
                      hint: 'Interview from (11:00)',
                      controller: interviewStartController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Input(
                      hint: 'Interview to (16:00)',
                      controller: interviewEndController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Input(
                hint: 'Different interview address (optional)',
                controller: interviewAddressController,
              ),
            ] else ...[
              const SizedBox(height: 12),
              _ReviewLine(
                'Role',
                titleController.text.trim().isEmpty
                    ? 'Add a job title below'
                    : titleController.text.trim(),
              ),
              _ReviewLine(
                'Location',
                [city, state].whereType<String>().join(', ').isEmpty
                    ? 'Add city and state below'
                    : [city, state].whereType<String>().join(', '),
              ),
              _ReviewLine(
                'Reach',
                reach == 'nearby'
                    ? 'Nearby (within 10 km)'
                    : 'Anywhere in the city',
              ),
              const SizedBox(height: 8),
              const Text(
                'Never ask a karigar for money that is not written on this job.',
                style: TextStyle(color: AppColors.amber, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dayChips(Set<String> selected) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        .map(
          (day) => _Choice(
            text: day,
            selected: selected.contains(day),
            onTap: () => setState(
              () => selected.contains(day)
                  ? selected.remove(day)
                  : selected.add(day),
            ),
          ),
        )
        .toList(),
  );

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _reachCityDebounce?.cancel();
    _locationDebounce?.cancel();
    _errorBannerTimer?.cancel();
    workHoursController.removeListener(_refreshCoreHoursValidation);
    titleController.removeListener(_titleChanged);
    titleController.dispose();
    openingsController.dispose();
    experienceController.dispose();
    experienceMaxController.dispose();
    wageMinController.dispose();
    wageMaxController.dispose();
    descriptionController.dispose();
    contactPhoneController.dispose();
    addressController.dispose();
    areaController.dispose();
    shiftStartController.dispose();
    shiftEndController.dispose();
    workHoursController.dispose();
    contactNameController.dispose();
    contactDesignationController.dispose();
    perkController.dispose();
    incentiveMaxController.dispose();
    incentiveTypeController.dispose();
    otherRequirementsController.dispose();
    ageMinController.dispose();
    ageMaxController.dispose();
    interviewStartController.dispose();
    interviewEndController.dispose();
    interviewAddressController.dispose();
    workerFeePurposeController.dispose();
    reachCityController.dispose();
    customSkillController.dispose();
    customLanguageController.dispose();
    customAssetController.dispose();
    workerFeeAmountController.dispose();
    _formScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildStepWizard(context);
  }

  Widget _buildStepWizard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => _step == 0
              ? Navigator.maybePop(context)
              : setState(() => _step--),
        ),
        title: Text(
          widget.job == null ? 'Post a Job' : 'Edit Job',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Text(
                '${_step + 1}/4',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
        ],
      ),
      body: referenceLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _wizardStepper(),
                Expanded(
                  child: ListView(
                    controller: _formScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      if (formErrors.isNotEmpty) ...[
                        _JobErrorSummary(
                          errors: formErrors,
                          onDismiss: () =>
                              setState(() => formErrors = const []),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_step == 0) _stepOneContent(),
                      if (_step == 1) _stepTwoContent(),
                      if (_step == 2) _stepThreeContent(),
                      if (_step == 3) _stepFourContent(),
                      /* legacy comprehensive editor retained below temporarily */
                      if (false) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label('Job title', required: true),
                                  _JobTitlePicker(
                                    controller: titleController,
                                    profiles: jobProfiles,
                                    onProfileSelected: _selectJobProfile,
                                    onAddOwnTitle: _addOwnTitle,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label('Category', required: true),
                                  _Select(
                                    _otherCategorySelected
                                        ? 'Other (not in the list)'
                                        : category ?? 'Select category',
                                    onTap: _chooseCategory,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const _Hint(
                          'Pick from the list, or add your own title.',
                        ),
                        if (_otherCategorySelected) ...[
                          const SizedBox(height: 6),
                          const _Hint(
                            'Karigars find this job only by searching. If a craft comes close, pick that instead.',
                          ),
                        ] else if (_categoryWasSuggested) ...[
                          const SizedBox(height: 6),
                          const _Hint(
                            'Suggested from the job title. Change it if it is wrong.',
                          ),
                        ] else if (titleController.text.trim().isNotEmpty &&
                            category == null) ...[
                          const SizedBox(height: 6),
                          const _Hint(
                            'Pick the closest craft, so the right karigars get this job.',
                          ),
                        ],
                        const SizedBox(height: 14),
                        const _Label('Who can apply'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Choice(
                              text: 'Not specified',
                              selected: gender == null,
                              onTap: () => setState(() => gender = null),
                            ),
                            ...genderOptions.map(
                              (option) => _Choice(
                                text: option['label']!,
                                selected: gender == option['value'],
                                onTap: () =>
                                    setState(() => gender = option['value']),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const _Label('Skills required'),
                        if (category == null)
                          const _Hint(
                            'Select a category first to see matching skills.',
                          )
                        else ...[
                          if (selectedSkills.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: selectedSkills
                                  .map(
                                    (skill) => InputChip(
                                      label: Text(skill),
                                      onDeleted: () => setState(() {
                                        selectedSkills.remove(skill);
                                        _suggestedSkills.remove(skill);
                                        _skillsCameFromSuggestion = false;
                                      }),
                                    ),
                                  )
                                  .toList(),
                            ),
                          if (selectedSkills.isNotEmpty)
                            const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: skills
                                .where(
                                  (skill) => !selectedSkills.contains(skill),
                                )
                                .map(
                                  (skill) => _Choice(
                                    text: skill,
                                    selected: false,
                                    onTap: () => setState(() {
                                      selectedSkills.add(skill);
                                      _skillsCameFromSuggestion = false;
                                    }),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          _Input(
                            hint: 'Add a skill',
                            controller: perkController,
                            onSubmitted: (value) {
                              final skill = value.trim();
                              if (skill.isNotEmpty) {
                                setState(() {
                                  skills = {...skills, skill}.toList();
                                  selectedSkills.add(skill);
                                  _skillsCameFromSuggestion = false;
                                  perkController.clear();
                                });
                              }
                            },
                          ),
                          const _Hint(
                            'Tap to add. Karigars with these skills are matched first.',
                          ),
                        ],
                        const _SectionLabel('Work setup'),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label('Openings', required: true),
                                  _Input(
                                    hint: '3',
                                    controller: openingsController,
                                    number: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label('Min experience'),
                                  _Input(
                                    hint: '1',
                                    suffix: 'yrs',
                                    controller: experienceController,
                                    number: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label('Max experience'),
                                  _Input(
                                    hint: '5',
                                    suffix: 'yrs',
                                    controller: experienceMaxController,
                                    number: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const _SectionLabel('Salary'),
                        const Text(
                          'Enter monthly salary in rupees',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label(
                                    'Minimum / month',
                                    required: true,
                                  ),
                                  _Input(
                                    hint: '15000',
                                    prefix: '₹',
                                    controller: wageMinController,
                                    number: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label('Maximum / month'),
                                  _Input(
                                    hint: '30000',
                                    prefix: '₹',
                                    controller: wageMaxController,
                                    number: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const _Label('Shift'),
                        _singleChips(
                          ['Day', 'Night', 'Rotational', 'Flexible'],
                          shift,
                          _changeShift,
                        ),
                        const SizedBox(height: 14),
                        if (shift == 'Day' || shift == 'Night')
                          Row(
                            children: [
                              Expanded(
                                child: _TimeInput(
                                  label: 'Start time',
                                  value: shiftStartTime,
                                  onTap: () => _pickTime(start: true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _TimeInput(
                                  label: 'End time',
                                  value: shiftEndTime,
                                  onTap: () => _pickTime(start: false),
                                ),
                              ),
                            ],
                          )
                        else if (shift == 'Rotational')
                          _RotationalShiftEditor(
                            timings: rotationalTimings,
                            maxTimings: maxShiftTimings,
                            onPick: _pickRotationalTime,
                            onAdd: () => setState(
                              () => rotationalTimings.add(_ShiftTiming('', '')),
                            ),
                            onRemove: (index) => setState(
                              () => rotationalTimings.removeAt(index),
                            ),
                          )
                        else
                          _FlexibleShiftEditor(
                            hoursController: workHoursController,
                            period: workHoursPeriod,
                            addCoreHours: addCoreHours,
                            coreStart: coreStartTime,
                            coreEnd: coreEndTime,
                            coreHoursError: _coreHoursError,
                            onPeriodChanged: (value) =>
                                setState(() => workHoursPeriod = value),
                            onCoreChanged: (value) =>
                                setState(() => addCoreHours = value),
                            onPickCore: _pickCoreTime,
                          ),
                        const SizedBox(height: 14),
                        const _Label('Perks & benefits'),
                        _chips(perks, selectedPerks, multi: true),
                        const SizedBox(height: 8),
                        _Input(
                          hint: 'Add your own perk',
                          controller: perkController,
                          onSubmitted: (value) {
                            final perk = value.trim();
                            if (perk.isNotEmpty) {
                              setState(() {
                                perks = {...perks, perk}.toList();
                                selectedPerks.add(perk);
                                perkController.clear();
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        const _Label('Does the karigar pay anything?'),
                        _singleChips(
                          ['No — free to join', 'Yes — the karigar pays a fee'],
                          requiresWorkerFee
                              ? 'Yes — the karigar pays a fee'
                              : 'No — free to join',
                          (value) => setState(
                            () => requiresWorkerFee = value.startsWith('Yes'),
                          ),
                        ),
                        if (requiresWorkerFee) ...[
                          const SizedBox(height: 8),
                          _Input(
                            hint: 'Fee amount',
                            prefix: '₹',
                            number: true,
                            controller: workerFeeAmountController,
                          ),
                          const SizedBox(height: 8),
                          _Input(
                            hint: 'What is it for? (optional)',
                            controller: workerFeePurposeController,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _AiHelpCard(
                          shortlistEnabled: aiShortlistEnabled,
                          callEnabled: aiCallEnabled,
                          shortlistAvailable: aiShortlistAvailable,
                          callAvailable: aiCallAvailable,
                          creditsEnabled: aiCreditsEnabled,
                          creditsCanEnable: aiCreditsCanEnable,
                          creditsBalance: aiCreditsBalance,
                          creditsMinForJob: aiCreditsMinForJob,
                          onRecharge: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AiCreditsScreen(),
                            ),
                          ),
                          onShortlistChanged: aiShortlistAvailable
                              ? (value) =>
                                    setState(() => aiShortlistEnabled = value)
                              : null,
                          onCallChanged: aiCallAvailable && aiShortlistEnabled
                              ? (value) => setState(() => aiCallEnabled = value)
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _Label('Job description', required: true),
                            Wrap(
                              spacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _singleChips(
                                  ['en', 'hi'],
                                  aiLanguage,
                                  (value) => setState(() => aiLanguage = value),
                                ),
                                TextButton.icon(
                                  onPressed: suggesting
                                      ? null
                                      : _suggestDescription,
                                  icon: suggesting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          LucideIcons.sparkles,
                                          size: 16,
                                        ),
                                  label: Text(
                                    aiLanguage == 'hi'
                                        ? 'हिंदी में AI सुझाव'
                                        : 'Suggest with AI',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        _Input(
                          hint:
                              'Describe the work, site details, duration, tools provided…',
                          lines: 4,
                          controller: descriptionController,
                        ),
                        const _SectionLabel('Work & interview'),
                        _WorkInterviewCard(
                          workMode: workMode,
                          workModes: workModes,
                          onWorkModeChanged: (value) =>
                              setState(() => workMode = value),
                        ),
                        const _SectionLabel('Location'),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label('State', required: true),
                                  _Select(
                                    state ?? 'Select',
                                    onTap: () => _choose(
                                      'Select state',
                                      states,
                                      _loadCities,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label('City', required: true),
                                  _Select(
                                    city ?? 'Select',
                                    onTap: () {
                                      if (state == null) {
                                        _message('Select a state first.');
                                      } else {
                                        _choose('Select city', cities, (value) {
                                          setState(() {
                                            city = value;
                                            selectedLocation = null;
                                          });
                                          unawaited(_pinFromEnteredLocation());
                                        }, citySearch: true);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const _Label('Area / locality'),
                        _Input(
                          hint: 'e.g. Sector 45, Andheri West',
                          controller: areaController,
                          onSubmitted: (_) => _pinFromEnteredLocation(),
                        ),
                        const SizedBox(height: 14),
                        const _Label('Address / landmark'),
                        _Input(
                          hint: 'Plot, street or landmark',
                          controller: addressController,
                        ),
                        const SizedBox(height: 14),
                        const _Label('Pin the job location'),
                        SizedBox(
                          height: 190,
                          child: LocationMap(
                            key: ValueKey(
                              '$state/$city/${selectedLocation?.latitude}/${selectedLocation?.longitude}',
                            ),
                            initialLocation:
                                selectedLocation ??
                                const LatLng(22.5937, 78.9629),
                            initialZoom: selectedLocation == null ? 4 : 13,
                            hasSelection: selectedLocation != null,
                            onLocationChanged: (point) =>
                                unawaited(_syncLocationFromMap(point)),
                          ),
                        ),
                        const Text(
                          'Move the map or tap to pin the exact work site.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        const _SectionLabel('Applicant reach'),
                        const _Label('How should karigars reach you?'),
                        _singleChips(
                          ['Apply in the app', 'Call me directly', 'Both'],
                          contact,
                          (value) => setState(() => contact = value),
                        ),
                        if (contact != 'Apply in the app') ...[
                          const SizedBox(height: 14),
                          const _Label('Contact phone', required: true),
                          _Input(
                            hint: '9876543210',
                            controller: contactPhoneController,
                            number: true,
                            maxLength: 10,
                            errorText: contactPhoneError,
                            onChanged: (value) => setState(
                              () => contactPhoneError =
                                  value.isEmpty ||
                                      RegExp(r'^[6-9]\d{9}$').hasMatch(value)
                                  ? null
                                  : 'Enter a valid 10-digit number.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _Label('Who picks up the call?'),
                          _Input(
                            hint: 'e.g. Ramesh Kumar',
                            controller: contactNameController,
                          ),
                          const SizedBox(height: 12),
                          const _Label('Designation', required: true),
                          _Input(
                            hint: 'e.g. Site supervisor',
                            controller: contactDesignationController,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 11, 16, 20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (canDraft)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading ? null : () => _submit('draft'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              foregroundColor: colors.onSurface,
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                            child: Text(
                              widget.job == null ? 'Save draft' : 'Save draft',
                            ),
                          ),
                        ),
                      if (canDraft) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: loading
                              ? null
                              : _step < 3
                              ? _goNext
                              : () => _submit(canDraft ? 'active' : liveStatus),
                          child: Text(
                            loading
                                ? 'Saving...'
                                : _step < 3
                                ? 'Next'
                                : widget.job == null
                                ? 'Post job'
                                : editingDraft
                                ? 'Publish'
                                : 'Save changes',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _chips(
    List<String> values,
    Set<String> selected, {
    required bool multi,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: values
        .map(
          (value) => _Choice(
            text: _chipLabel(value),
            selected: selected.contains(value),
            onTap: () => setState(() {
              selected.contains(value)
                  ? selected.remove(value)
                  : selected.add(value);
            }),
          ),
        )
        .toList(),
  );

  Widget _chipsWithCustom(List<String> defaults, Set<String> selected) {
    final values = [
      ...defaults,
      ...selected.where((value) => !defaults.contains(value)),
    ];
    return _chips(values, selected, multi: true);
  }

  String _chipLabel(String value) =>
      {
        'any': 'Anyone',
        'freshers': 'Freshers',
        'experienced': 'Experienced',
        'both': 'Men & women',
        'male': 'Men',
        'female': 'Women',
        'basic': 'Basic',
        'good': 'Good',
        'fluent': 'Fluent',
        'nearby': 'Nearby',
        'city': 'From a city',
        'immediate': 'Urgent — within 1–2 weeks',
        'can_wait': 'No rush',
      }[value] ??
      value;

  Widget _singleChips(
    List<String> values,
    String selected,
    ValueChanged<String> onChanged,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: values
        .map(
          (value) => _Choice(
            text: _chipLabel(value),
            selected: value == selected,
            onTap: () => onChanged(value),
          ),
        )
        .toList(),
  );

  Future<void> _choose(
    String title,
    List<String> values,
    ValueChanged<String> onSelected, {
    bool citySearch = false,
  }) async {
    if (values.isEmpty) {
      _message('Options are not available yet. Please try again.');
      return;
    }
    final result = await showSearchableOptionSheet(
      context,
      title: title,
      values: values,
      citySearch: citySearch,
      stateName: state,
    );
    if (result != null) onSelected(result);
  }
}

class _ShiftDefault {
  const _ShiftDefault(this.start, this.end);
  final String start, end;
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _ShiftTiming {
  _ShiftTiming(this.start, this.end);
  String start, end;
}

class _RotationalShiftEditor extends StatelessWidget {
  const _RotationalShiftEditor({
    required this.timings,
    required this.maxTimings,
    required this.onPick,
    required this.onAdd,
    required this.onRemove,
  });
  final List<_ShiftTiming> timings;
  final int maxTimings;
  final Future<void> Function(int, {required bool start}) onPick;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ...timings.indexed.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(width: 54, child: Text('Shift ${entry.$1 + 1}')),
              Expanded(
                child: _TimeInput(
                  label: 'Start',
                  value: _parse(entry.$2.start),
                  onTap: () => onPick(entry.$1, start: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimeInput(
                  label: 'End',
                  value: _parse(entry.$2.end),
                  onTap: () => onPick(entry.$1, start: false),
                ),
              ),
              IconButton(
                tooltip: 'Remove shift timing',
                onPressed: timings.length > 1 ? () => onRemove(entry.$1) : null,
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: timings.length < maxTimings ? onAdd : null,
          icon: const Icon(LucideIcons.plus, size: 17),
          label: const Text('Add Shift Timing'),
        ),
      ),
    ],
  );

  TimeOfDay? _parse(String value) {
    final pieces = value.split(':');
    if (pieces.length != 2) return null;
    final hour = int.tryParse(pieces[0]);
    final minute = int.tryParse(pieces[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _FlexibleShiftEditor extends StatelessWidget {
  const _FlexibleShiftEditor({
    required this.hoursController,
    required this.period,
    required this.addCoreHours,
    required this.coreStart,
    required this.coreEnd,
    this.coreHoursError,
    required this.onPeriodChanged,
    required this.onCoreChanged,
    required this.onPickCore,
  });
  final TextEditingController hoursController;
  final String period;
  final bool addCoreHours;
  final TimeOfDay? coreStart, coreEnd;
  final String? coreHoursError;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<bool> onCoreChanged;
  final Future<void> Function({required bool start}) onPickCore;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: _Input(
              hint: '8',
              suffix: 'hours',
              controller: hoursController,
              number: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _singlePeriod(context)),
        ],
      ),
      const SizedBox(height: 8),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: addCoreHours,
        onChanged: onCoreChanged,
        title: const Text('Add Core Working Hours'),
        subtitle: const Text(
          'Time window when employee must be online/available',
          style: TextStyle(fontSize: 12),
        ),
      ),
      if (addCoreHours) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _TimeInput(
                label: 'Core start',
                value: coreStart,
                onTap: () => onPickCore(start: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeInput(
                label: 'Core end',
                value: coreEnd,
                onTap: () => onPickCore(start: false),
              ),
            ),
          ],
        ),
        if (coreHoursError != null) ...[
          const SizedBox(height: 8),
          Text(
            coreHoursError!,
            style: const TextStyle(color: AppColors.rose, fontSize: 12),
          ),
        ],
      ],
    ],
  );

  Widget _singlePeriod(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: period,
    decoration: const InputDecoration(labelText: 'Period'),
    items: const [
      DropdownMenuItem(value: 'day', child: Text('Per day')),
      DropdownMenuItem(value: 'week', child: Text('Per week')),
    ],
    onChanged: (value) {
      if (value != null) onPeriodChanged(value);
    },
  );
}

class _JobProfile {
  const _JobProfile({required this.title, required this.category});

  final String title;
  final String category;
}

class _JobTitlePicker extends StatefulWidget {
  const _JobTitlePicker({
    required this.controller,
    required this.profiles,
    required this.onProfileSelected,
    required this.onAddOwnTitle,
    this.hasError = false,
  });

  final TextEditingController controller;
  final List<_JobProfile> profiles;
  final ValueChanged<_JobProfile> onProfileSelected;
  final VoidCallback onAddOwnTitle;
  final bool hasError;

  @override
  State<_JobTitlePicker> createState() => _JobTitlePickerState();
}

class _JobTitlePickerState extends State<_JobTitlePicker> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focusNode.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _JobTitlePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focusNode
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  int _rank(_JobProfile profile, String query) {
    final title = profile.title.toLowerCase();
    if (title.startsWith(query)) return 0;
    if (title
        .split(RegExp(r'[^a-z0-9]+'))
        .any((word) => word.startsWith(query))) {
      return 1;
    }
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim();
    final normalized = query.toLowerCase();
    final matches = normalized.isEmpty
        ? <_JobProfile>[]
        : widget.profiles
              .where(
                (profile) => profile.title.toLowerCase().contains(normalized),
              )
              .toList();
    matches.sort((a, b) {
      final rank = _rank(a, normalized).compareTo(_rank(b, normalized));
      return rank != 0 ? rank : a.title.compareTo(b.title);
    });
    final exactMatch = widget.profiles.any(
      (profile) => profile.title.toLowerCase() == normalized,
    );
    final showChoices = _focusNode.hasFocus && query.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          maxLength: 255,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Type job title',
            counterText: '',
            prefixIcon: Icon(LucideIcons.search, size: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.hasError ? AppColors.rose : AppColors.line,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.hasError ? AppColors.rose : AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (showChoices)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                ...matches
                    .take(8)
                    .map(
                      (profile) => _JobTitleOption(
                        profile: profile,
                        query: query,
                        onTap: () {
                          widget.onProfileSelected(profile);
                          _focusNode.unfocus();
                        },
                      ),
                    ),
                if (!exactMatch)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      LucideIcons.plus,
                      color: colors.primary,
                      size: 18,
                    ),
                    title: Text('Add "$query"'),
                    onTap: () {
                      widget.onAddOwnTitle();
                      _focusNode.unfocus();
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _JobTitleOption extends StatelessWidget {
  const _JobTitleOption({
    required this.profile,
    required this.query,
    required this.onTap,
  });

  final _JobProfile profile;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = profile.title;
    final index = title.toLowerCase().indexOf(query.toLowerCase());
    final style = DefaultTextStyle.of(context).style;
    final highlighted = index < 0
        ? TextSpan(text: title)
        : TextSpan(
            children: [
              TextSpan(text: title.substring(0, index)),
              TextSpan(
                text: title.substring(index, index + query.length),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: title.substring(index + query.length)),
            ],
          );
    return ListTile(
      dense: true,
      title: Text.rich(highlighted, style: style),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 105),
        child: Text(
          profile.category,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _WorkInterviewCard extends StatelessWidget {
  const _WorkInterviewCard({
    required this.workMode,
    required this.workModes,
    required this.onWorkModeChanged,
  });
  final String workMode;
  final List<Map<String, String>> workModes;
  final ValueChanged<String> onWorkModeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget options(
      List<Map<String, String>> values,
      String selected,
      ValueChanged<String> onChanged,
    ) => Column(
      children: values.map((item) {
        final value = item['value']!;
        final active = selected == value;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: active ? AppColors.brand50 : colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.line,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    active ? LucideIcons.circleDot : LucideIcons.circle,
                    size: 18,
                    color: active ? AppColors.primary : AppColors.line,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['label']!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(switch (value) {
                          'on_site' => 'Comes to your workshop or site',
                          'remote' => 'Works from their own home',
                          _ => 'Either: the karigar chooses',
                        }, style: TextStyle(color: colors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where will the karigar work?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          options(workModes, workMode, onWorkModeChanged),
        ],
      ),
    );
  }
}

class _PostJobHeader extends StatelessWidget {
  const _PostJobHeader({required this.editing, required this.draft});
  final bool editing, draft;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.brandDark, AppColors.gradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x294F1B0D),
          blurRadius: 16,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? (draft ? 'DRAFT JOB' : 'JOB LISTING') : 'NEW JOB',
                style: const TextStyle(
                  color: Color(0xFFFBECE5),
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                editing ? 'Complete your listing' : 'Find the right karigar',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Add clear details to get better applications.',
                style: TextStyle(color: Color(0xFFFBECE5), fontSize: 12.5),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x40FFFFFF)),
          ),
          child: const Icon(LucideIcons.filePenLine, color: Colors.white),
        ),
      ],
    ),
  );
}

class _AiHelpCard extends StatelessWidget {
  const _AiHelpCard({
    required this.shortlistEnabled,
    required this.callEnabled,
    required this.shortlistAvailable,
    required this.callAvailable,
    required this.onShortlistChanged,
    required this.onCallChanged,
    required this.creditsEnabled,
    required this.creditsCanEnable,
    required this.creditsBalance,
    required this.creditsMinForJob,
    required this.onRecharge,
  });

  final bool shortlistEnabled, callEnabled, shortlistAvailable, callAvailable;
  final ValueChanged<bool>? onShortlistChanged, onCallChanged;
  final bool creditsEnabled, creditsCanEnable;
  final int creditsBalance, creditsMinForJob;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.brand50,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI help',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _AiSwitch(
            title: 'AI shortlist',
            description:
                'AI scores every applicant. Strong matches are shortlisted for you and clear mismatches are turned down.',
            value: shortlistEnabled,
            onChanged: onShortlistChanged,
            note: shortlistAvailable
                ? null
                : 'Switched off by the admin right now.',
          ),
          const Divider(height: 22),
          _AiSwitch(
            title: 'AI screening call',
            description:
                'An AI agent calls each auto-shortlisted karigar to check they are still interested and asks a few first questions. You get the answers.',
            value: callEnabled,
            onChanged: !creditsEnabled || creditsCanEnable
                ? onCallChanged
                : null,
            note: !callAvailable
                ? 'Switched off by the admin right now.'
                : !shortlistEnabled
                ? 'Needs AI shortlist on.'
                : creditsEnabled && !creditsCanEnable
                ? 'AI call credits: $creditsBalance · needs at least $creditsMinForJob to switch AI calls on.'
                : null,
          ),
          if (creditsEnabled) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'AI call credits: ',
                        style: const TextStyle(color: AppColors.muted),
                        children: [
                          TextSpan(
                            text: '$creditsBalance',
                            style: const TextStyle(
                              color: AppColors.foreground,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRecharge,
                    child: const Text('Recharge'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Your AI preferences are applied when you save or publish this job.',
            style: TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
      ),
    ),
  );
}

class _AiSwitch extends StatelessWidget {
  const _AiSwitch({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.note,
  });

  final String title, description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? note;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onChanged == null ? null : () => onChanged!(!value),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: onChanged == null ? AppColors.muted : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (note != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    note!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});
  final String text;
  final bool required;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.rose),
            ),
        ],
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _JobErrorSummary extends StatelessWidget {
  const _JobErrorSummary({required this.errors, required this.onDismiss});
  final List<String> errors;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
    decoration: BoxDecoration(
      color: AppColors.rose.withValues(alpha: .10),
      border: Border.all(color: AppColors.rose.withValues(alpha: .4)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(LucideIcons.circleAlert, color: AppColors.rose, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please fix these details',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              ...errors.map(
                (error) =>
                    Text('• $error', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onDismiss,
          icon: const Icon(LucideIcons.x, size: 18),
        ),
      ],
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.hint,
    this.lines = 1,
    this.prefix,
    this.suffix,
    this.controller,
    this.number = false,
    this.maxLength,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
  });
  final String hint;
  final int lines;
  final String? prefix;
  final String? suffix;
  final TextEditingController? controller;
  final bool number;
  final int? maxLength;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onSubmitted: onSubmitted,
    onChanged: onChanged,
    onTap: onTap,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    inputFormatters: number
        ? [
            FilteringTextInputFormatter.digitsOnly,
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ]
        : null,
    maxLines: lines,
    maxLength: maxLength,
    decoration: InputDecoration(
      hintText: hint,
      errorText: errorText,
      counterText: '',
      prefixIconConstraints: const BoxConstraints(minWidth: 34),
      prefixIcon: prefix == null
          ? null
          : Center(widthFactor: 1, child: Text(prefix!)),
      suffixIcon: suffix == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                widthFactor: 1,
                child: Text(
                  suffix!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
    ),
  );
}

class _TimeInput extends StatelessWidget {
  const _TimeInput({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(LucideIcons.clock3, size: 19),
      ),
      child: Text(
        value == null ? 'Select time' : value!.format(context),
        style: TextStyle(
          color: value == null
              ? AppColors.muted
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );
}

class _Select extends StatelessWidget {
  const _Select(this.text, {this.onTap, this.errorText});
  final String text;
  final VoidCallback? onTap;
  final String? errorText;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(
                color: errorText == null ? AppColors.line : AppColors.rose,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 14)),
                ),
                const Icon(LucideIcons.chevronDown, size: 16),
              ],
            ),
          ),
        ),
        if (errorText != null) _InlineFieldError(errorText!),
      ],
    );
  }
}

class _InlineFieldError extends StatelessWidget {
  const _InlineFieldError(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 2),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.rose, fontSize: 12, height: 1.2),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 19,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppColors.line2, height: 1)),
      ],
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.text,
    required this.selected,
    required this.onTap,
  });
  final String text;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.card,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.muted,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}
