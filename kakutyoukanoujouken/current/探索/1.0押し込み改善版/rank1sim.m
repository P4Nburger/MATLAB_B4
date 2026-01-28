% =========================================================================
% Rank 1 パラメータでの完全シミュレーション
% 1. 周波数スイープで共振周波数を特定
% 2. 共振周波数で本番時刻歴シミュレーション
% gouseihenkou.m ベース、パラメータのみ Rank 1
% =========================================================================
clear; clc; close all;

% -------------------------------------------------------------------------
% 1. Rank 1 パラメータ設定
% -------------------------------------------------------------------------
% --- Rank 1 設計パラメータ ---
x_push = 0.020e-3;      % [m] = 0.020 mm
w1_stiff = 0.10e-3;     % [m] = 0.10 mm (剛性計算用)
w1_mass = 100.0e-3;     % [m] = 100.0 mm (質量・面積計算用)
L = 25.0e-3;            % [m] = 25.0 mm

% --- スイープ設定 ---
freq_range = 20:1:40;   % [Hz] スイープ範囲
tspan_sweep = [0 2.0];  % [s] スイープ時の計算時間

% --- 音波設定 ---
P0_drive = 2;           % [Pa]

% --- 本番シミュレーション設定 ---
tspan_main = [0 5.0];   % [s]
t_sound_on = 1.0;       % [s] 本番での音波ON時刻

% --- 初期たわみ設定 ---
C_eff = 0.2794;         % 有効形状定数
z_target_initial_mm = sqrt(2 * (x_push * 1000) / C_eff); % [mm]
z_target_initial = z_target_initial_mm / 1000; % [m]

% --- 構造・材料パラメータ ---
params = struct( ...
    'L', L, ...
    'w1_stiff', w1_stiff, ...
    'w1_mass', w1_mass, ...
    't1', 0.1e-3, ...       % [m]
    'E1', 3.45e9, ...       % [Pa]
    'rho1', 1250, ...       % [kg/m^3]
    'S2', 152.522e-6, ...   % [m^2]
    'rho2', 1250, ...       % [kg/m^3]
    'k2_base', 222.0, ...   % [N/m]
    'delta', 0.05, ...      % 減衰比
    'P0', P0_drive, ...     % [Pa]
    'freq', 0 ...           % [Hz]（後で上書き）
);

% -------------------------------------------------------------------------
% 2. 物理定数と「真の平衡点」の計算
% -------------------------------------------------------------------------
% ★質量 m1 は「全体の重さ」なので、平均幅 (w1_mass) を使う
params.m1 = params.rho1 * params.L * params.w1_mass * params.t1;
params.m2 = params.rho2 * params.S2 * params.L;

% ★断面二次モーメント I1 は「曲がりにくさ」なので、一番細い部分 (w1_stiff) で決まる
params.I1 = params.w1_stiff * params.t1^3 / 12;

% ★バネ定数 k1 も「細い部分」の特性で決まる
params.k1 = 384 * params.E1 * params.I1 / (params.L^3);

% ★幾何学的連成 K_couple も「細い部分」が伸び縮みするので w1_stiff
params.K_couple = params.E1 * (params.w1_stiff * params.t1) / params.L;

params.c1 = 2 * params.delta * sqrt(params.m1 * params.k1);
params.c2 = 2 * params.delta * sqrt(params.m2 * params.k2_base);

% --- 幾何学係数 Gamma ---
params.Gamma = (C_eff / 2) * 1000; % [1/m]

% --- 欲しい初期たわみを z_eq として固定 ---
z_eq = z_target_initial;

% ラグランジュからの厳密な釣り合い条件：
coupling_eq = params.k1 / (2 * params.Gamma * params.K_couple);
y_eq = params.Gamma * z_eq^2 + coupling_eq;
y_natural = y_eq + (params.K_couple * coupling_eq) / params.k2_base;

params.z_eq = z_eq;
params.y_eq = y_eq;
params.y_natural = y_natural;

fprintf('========================================\n');
fprintf('   Rank 1 Parameters\n');
fprintf('========================================\n');
fprintf('x_push:       %.3f mm\n', x_push * 1000);
fprintf('w1_stiff:     %.2f mm\n', w1_stiff * 1000);
fprintf('w1_mass:      %.1f mm\n', w1_mass * 1000);
fprintf('L:            %.1f mm\n', L * 1000);
fprintf('----------------------------------------\n');
fprintf('z_eq:         %.3f mm\n', z_eq * 1000);
fprintf('y_eq:         %.3f mm\n', y_eq * 1000);
fprintf('y_natural:    %.3f mm\n', y_natural * 1000);
fprintf('k1:           %.2f N/m\n', params.k1);
fprintf('m1:           %.6f kg\n', params.m1);
fprintf('========================================\n\n');

% 初期条件（真の力の釣り合い点で静止からスタート）
x0 = [z_eq; y_eq; 0; 0];

% -------------------------------------------------------------------------
% 3. 周波数スイープの実行
% -------------------------------------------------------------------------
fprintf('周波数スイープを実行中...\n');
amp_data = zeros(size(freq_range));
h_wait = waitbar(0, '周波数スイープ中...');

for i = 1:length(freq_range)
    f_curr = freq_range(i);
    waitbar(i/length(freq_range), h_wait, sprintf('解析中: %.0f Hz', f_curr));
    
    params_sweep = params;
    params_sweep.freq = f_curr;
    
    % スイープ時は音波を最初からON (t_sound_on = 0)
    [~, x_sw] = ode45(@(t,x) equations_2DOF_SelfSustain(t, x, params_sweep, 0), ...
        tspan_sweep, x0);
    
    z_sw = x_sw(:,1);
    % 後半の定常振動から振幅を取得
    z_steady = z_sw(round(end/2):end);
    amp_data(i) = (max(z_steady) - min(z_steady)) / 2;
end

close(h_wait);

[max_amp, idx_res] = max(amp_data);
f_res = freq_range(idx_res);

fprintf('スイープ完了。\n');
fprintf('共振周波数: %.2f Hz (振幅: %.3f mm)\n\n', f_res, max_amp*1000);

% -------------------------------------------------------------------------
% 4. 本番シミュレーション (共振周波数にて)
% -------------------------------------------------------------------------
fprintf('共振周波数での時間応答を計算中...\n');
params.freq = f_res;
options = odeset('RelTol', 1e-6, 'AbsTol', 1e-9);

[t, x] = ode45(@(t,x) equations_2DOF_SelfSustain(t, x, params, t_sound_on), ...
    tspan_main, x0, options);

z = x(:,1);
y = x(:,2);
dz = x(:,3);
dy = x(:,4);

fprintf('計算完了。\n\n');

% -------------------------------------------------------------------------
% 5. スナップスルー判定
% -------------------------------------------------------------------------
threshold = 0.05 * abs(z_eq);  % [m]
z_max = max(z) * 1000;
z_min = min(z) * 1000;

in_positive = z > threshold;
in_negative = z < -threshold;

pos_entries = 0;
neg_entries = 0;
currently_in_pos = false;
currently_in_neg = false;

for j = 1:length(z)
    if in_positive(j)
        if ~currently_in_pos
            pos_entries = pos_entries + 1;
            currently_in_pos = true;
            currently_in_neg = false;
        end
    elseif in_negative(j)
        if ~currently_in_neg
            neg_entries = neg_entries + 1;
            currently_in_neg = true;
            currently_in_pos = false;
        end
    end
end

crosses_zero = (pos_entries > 0) && (neg_entries > 0);
n_crosses = pos_entries + neg_entries - 1;

fprintf('========================================\n');
fprintf('   Snapthrough Analysis\n');
fprintf('========================================\n');
fprintf('z range:         %.3f ~ %.3f mm\n', z_min, z_max);
fprintf('z_eq:            %.3f mm\n', z_eq * 1000);
fprintf('threshold:       %.3f mm\n', threshold * 1000);
fprintf('Positive visits: %d\n', pos_entries);
fprintf('Negative visits: %d\n', neg_entries);
fprintf('Zero crossings:  %d\n', n_crosses);
if crosses_zero
    fprintf('Result:          SNAPTHROUGH!\n');
else
    fprintf('Result:          No snapthrough\n');
end
fprintf('========================================\n\n');

% -------------------------------------------------------------------------
% 6. プロット
% -------------------------------------------------------------------------
% --- Figure 1: 周波数応答 ---
figure('Position', [50, 100, 600, 400], 'Color', 'w');
plot(freq_range, amp_data*1000, 'b.-', 'LineWidth', 1.5);
hold on;
plot(f_res, max_amp*1000, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
hold off;
title('周波数応答 (Rank 1)');
xlabel('周波数 [Hz]'); 
ylabel('Z方向 振幅 [mm]');
grid on; 
legend('応答曲線', sprintf('共振点: %.1f Hz', f_res), 'Location', 'best');

% --- Figure 2: 時間応答 ---
figure('Position', [700, 100, 1400, 900], 'Color', 'w');

% (1) Z方向 (膜)
subplot(3,2,1);
plot(t, z*1000, 'b-', 'LineWidth', 1.5);
hold on;
xline(t_sound_on, 'r--', 'LineWidth', 1.5, 'Label', 'Sound ON');
yline(z_eq*1000, 'k:', 'Label', '初期位置');
yline(0, 'g--', 'LineWidth', 1);
yline(threshold*1000, 'm:', 'LineWidth', 1);
yline(-threshold*1000, 'm:', 'LineWidth', 1);
hold off;
ylabel('Z 変位 [mm]');
title(sprintf('膜のたわみ (Z) (駆動: %.2f Hz)', f_res));
grid on;
xlim([0 5]);

% (2) Y方向 (フレーム)
subplot(3,2,2);
% 拡張量としてプロット (y_eq - y)
y_extension = (params.y_eq - y) * 1000;
plot(t, y_extension, 'r-', 'LineWidth', 1.5);
hold on;
xline(t_sound_on, 'r--', 'LineWidth', 1.5);
yline(0, 'g:', 'LineWidth', 1.5, 'Label', '初期位置');
hold off;
ylabel('拡張量 [mm]');
title('フレームの変位 (Y)');
grid on;
xlim([0 5]);

% (3) Z速度
subplot(3,2,3);
plot(t, dz*1000, 'b-', 'LineWidth', 1);
hold on;
xline(t_sound_on, 'r--', 'LineWidth', 1.5);
yline(0, 'k:', 'LineWidth', 1);
hold off;
xlabel('Time [s]'); ylabel('dz/dt [mm/s]');
title('膜の速度');
grid on; xlim([0 5]);

% (4) Y速度
subplot(3,2,4);
plot(t, dy*1000, 'r-', 'LineWidth', 1);
hold on;
xline(t_sound_on, 'r--', 'LineWidth', 1.5);
yline(0, 'k:', 'LineWidth', 1);
hold off;
xlabel('Time [s]'); ylabel('dy/dt [mm/s]');
title('フレームの速度');
grid on; xlim([0 5]);

% (5) 位相平面 (Z)
subplot(3,2,5);
plot(z*1000, dz*1000, 'b-', 'LineWidth', 1);
hold on;
plot(z(1)*1000, dz(1)*1000, 'go', 'MarkerSize', 10, 'LineWidth', 2);
plot(z(end)*1000, dz(end)*1000, 'rs', 'MarkerSize', 10, 'LineWidth', 2);
xline(0, 'k--', 'LineWidth', 1);
yline(0, 'k--', 'LineWidth', 1);
hold off;
xlabel('Z [mm]'); ylabel('dz/dt [mm/s]');
title(sprintf('位相平面 (Z) - %d crossings', n_crosses));
legend('軌道', 'スタート', '終了', 'Location', 'best');
grid on;

% (6) 位相平面 (Y)
subplot(3,2,6);
plot((y-y_eq)*1000, dy*1000, 'r-', 'LineWidth', 1);
hold on;
plot((y(1)-y_eq)*1000, dy(1)*1000, 'go', 'MarkerSize', 10, 'LineWidth', 2);
plot((y(end)-y_eq)*1000, dy(end)*1000, 'rs', 'MarkerSize', 10, 'LineWidth', 2);
xline(0, 'k--', 'LineWidth', 1);
yline(0, 'k--', 'LineWidth', 1);
hold off;
xlabel('Y - y_{eq} [mm]'); ylabel('dy/dt [mm/s]');
title('位相平面 (Y)');
legend('軌道', 'スタート', '終了', 'Location', 'best');
grid on;

sgtitle(sprintf('Rank 1 時刻歴シミュレーション (f_{res}=%.2f Hz)', f_res), ...
    'FontSize', 14, 'FontWeight', 'bold');

% --- Figure 3: 拡大プロット（音波ON前後） ---
figure('Position', [100, 100, 1200, 400], 'Color', 'w');

t_window = [t_sound_on-0.2, t_sound_on+1.0];
idx_window = (t >= t_window(1)) & (t <= t_window(2));

subplot(1,2,1);
plot(t(idx_window), z(idx_window)*1000, 'b-', 'LineWidth', 1.5);
hold on;
xline(t_sound_on, 'r--', 'LineWidth', 2, 'Label', 'Sound ON');
yline(0, 'k:', 'LineWidth', 1);
yline(z_eq*1000, 'g--', 'LineWidth', 1, 'Label', 'z_{eq}');
hold off;
xlabel('Time [s]'); ylabel('Z [mm]');
title('膜の応答（拡大）');
grid on; xlim(t_window);

subplot(1,2,2);
plot(t(idx_window), y_extension(idx_window), 'r-', 'LineWidth', 1.5);
hold on;
xline(t_sound_on, 'r--', 'LineWidth', 2);
yline(0, 'k:', 'LineWidth', 1);
hold off;
xlabel('Time [s]'); ylabel('拡張量 [mm]');
title('フレーム拡張（拡大）');
grid on; xlim(t_window);

sgtitle('音波印加時の過渡応答', 'FontSize', 12, 'FontWeight', 'bold');

% =========================================================================
% 2自由度 運動方程式 (自立維持・剛性一定・音波あり)
% =========================================================================
function dx = equations_2DOF_SelfSustain(t, x, p, t_sound_on)
    z = x(1);
    y = x(2);
    dz = x(3);
    dy = x(4);
    
    % --- 1. 剛性は一定 (初期値のまま) ---
    k1_curr = p.k1;
    
    % --- 2. 復元力の計算 ---
    coupling_term = y - (p.Gamma * z^2);
    F_restore_z = k1_curr * z ...
        - p.K_couple * coupling_term * (2 * p.Gamma * z);
    F_restore_y = p.k2_base * (y - p.y_natural) ...
        + p.K_couple * coupling_term;
    
    % --- 3. 外力 (音波) ---
    if t >= t_sound_on
        % ランプを入れてショックを和らげる
        ramp = min(1.0, (t - t_sound_on)/0.1);
        % 音を受ける面積は「全体の面積」なので w1_mass を使う
        F_sound = ramp * p.P0 * (p.L * p.w1_mass) * cos(2 * pi * p.freq * t);
    else
        F_sound = 0;
    end
    
    % --- 4. 運動方程式 ---
    ddz = (F_sound - p.c1 * dz - F_restore_z) / p.m1;
    ddy = (0 - p.c2 * dy - F_restore_y) / p.m2;
    
    dx = [dz; dy; ddz; ddy];
end
